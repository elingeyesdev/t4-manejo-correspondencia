<?php

namespace App\Services;

use App\Models\InternalNote;
use App\Models\NoteNotice;
use App\Models\NoteNoticeDevice;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class NoteNotices
{
    public function forPendingNote(InternalNote $note): void
    {
        $event = 'nota:'.$note->version;
        if ($note->state === InternalNote::REVIEW) {
            $reviewer = $note->participants()->where('role', 'via')->where('position', $note->active_position)->value('user_id');
            $recipients = User::whereKey($reviewer)->where('enabled', true)
                ->whereHas('unit', fn ($unit) => $unit->where('enabled', true)->where('institution_id', $note->origin->institution_id))
                ->pluck('id');

            $this->record($note->id, NoteNotice::REVIEW, $event, $note->version, $recipients);
        } elseif ($note->state === InternalNote::RECEIVE) {
            $this->record($note->id, NoteNotice::INITIAL_RECEIPT, $event, $note->version,
                $this->receptionRecipients($note->recipient_unit_id));
        }
    }

    public function forDerivedReceipt(string $noteId, int $unit, int $version, string $movementId): void
    {
        $this->record($noteId, NoteNotice::DERIVED_RECEIPT, 'movimiento:'.$movementId, $version,
            $this->receptionRecipients($unit));
    }

    private function receptionRecipients(int $unit): iterable
    {
        return User::where('unit_id', $unit)->where('enabled', true)->where('role', 'funcionario')
            ->whereHas('unit', fn ($query) => $query->where('enabled', true))->pluck('id');
    }

    private function record(string $noteId, string $type, string $event, int $version, iterable $recipients): void
    {
        $instant = now();
        foreach ($recipients as $userId) {
            $notice = NoteNotice::firstOrCreate(
                ['note_id' => $noteId, 'event_key' => $event, 'user_id' => $userId],
                ['type' => $type, 'event_version' => $version, 'created_at' => $instant],
            );

            if ($notice->wasRecentlyCreated) {
                $devices = NoteNoticeDevice::where('user_id', $userId)->whereNotNull('access_token_id')
                    ->pluck('id')->map(fn (string $id) => ['notice_id' => $notice->id, 'device_id' => $id, 'available_at' => $instant]);
                DB::table('note_notice_deliveries')->insert($devices->all());
            }
        }
    }
}
