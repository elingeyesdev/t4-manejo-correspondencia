<?php

namespace App\Services;

use App\Models\InternalNote;
use App\Models\NoteNotice;
use App\Models\NoteNoticeDevice;
use App\Models\User;
use Exception;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Sanctum\PersonalAccessToken;

class DeliverNoteNotices
{
    private const MAX_ATTEMPTS = 8;

    public function __construct(private readonly FcmNoticeTransport $transport) {}

    public function run(): int
    {
        if (! config('fcm.project_id')) {
            return 0;
        }

        $ready = DB::table('note_notice_deliveries')->whereNull('finished_at')->where('available_at', '<=', now())
            ->orderBy('available_at')->orderBy('id')->limit(100)->get();
        $processed = 0;
        foreach ($ready as $delivery) {
            $processed += (int) $this->deliver($delivery);
        }

        return $processed;
    }

    private function deliver(object $delivery): bool
    {
        $lease = (string) Str::uuid();
        $row = DB::table('note_notice_deliveries')->where('id', $delivery->id)->whereNull('finished_at');
        $attempt = $delivery->attempts + 1;
        $claimed = (clone $row)->where('available_at', '<=', now())->where('attempts', $delivery->attempts)->update([
            'lease' => $lease,
            'available_at' => now()->addMinutes(2),
            'attempts' => $attempt,
        ]);
        if (! $claimed) {
            return false;
        }

        $row->where('lease', $lease);
        $notice = NoteNotice::find($delivery->notice_id);
        $device = NoteNoticeDevice::find($delivery->device_id);
        if ($attempt > self::MAX_ATTEMPTS) {
            $result = ['outcome' => 'exhausted'];
        } elseif ($notice === null || $device === null || ! $this->canSend($notice, $device)) {
            $result = ['outcome' => 'skipped'];
        } else {
            try {
                $result = $this->transport->send($device->fcm_token, $notice->id);
            } catch (Exception) {
                $result = ['outcome' => 'retry'];
            }
        }

        if ($result['outcome'] === 'unregistered') {
            NoteNoticeDevice::whereKey($device->id)->where('token_hash', $device->token_hash)
                ->where('access_token_id', $device->access_token_id)->update(['access_token_id' => null]);
        }

        if ($result['outcome'] === 'retry' && $attempt < self::MAX_ATTEMPTS) {
            $delay = max(60 * 2 ** ($attempt - 1), $result['delay'] ?? 0);
            $row->update(['outcome' => 'retry', 'available_at' => now()->addSeconds($delay), 'lease' => null]);
        } else {
            $row->update([
                'outcome' => $result['outcome'] === 'retry' ? 'exhausted' : $result['outcome'],
                'finished_at' => now(),
                'lease' => null,
            ]);
        }

        return true;
    }

    private function canSend(NoteNotice $notice, NoteNoticeDevice $device): bool
    {
        if ((int) $device->user_id !== (int) $notice->user_id || $device->access_token_id === null) {
            return false;
        }

        $session = PersonalAccessToken::find($device->access_token_id);
        $actor = $session?->tokenable;
        $expiration = config('sanctum.expiration');
        if (! $actor instanceof User || (int) $actor->id !== (int) $notice->user_id || ! $actor->isOperational()
            || $session->expires_at?->isPast()
            || ($expiration && $session->created_at->lte(now()->subMinutes($expiration)))) {
            return false;
        }

        $note = InternalNote::visibleTo($actor)->with('document.sheet')->find($notice->note_id);
        if ($note === null) {
            return false;
        }

        return match ($notice->type) {
            NoteNotice::REVIEW => $note->state === InternalNote::REVIEW && $note->version === $notice->event_version
                && $note->participants()->where('role', 'via')->where('position', $note->active_position)
                    ->where('user_id', $actor->id)->exists(),
            NoteNotice::INITIAL_RECEIPT => $note->state === InternalNote::RECEIVE && $note->version === $notice->event_version
                && $note->allowsInitialReceipt($actor),
            NoteNotice::DERIVED_RECEIPT => $note->document?->sheet?->canReceive($actor)
                && (int) $note->document->sheet->version === $notice->event_version,
        };
    }
}
