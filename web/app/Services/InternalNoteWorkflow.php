<?php

namespace App\Services;

use App\Models\InternalNote;
use App\Models\InternalNoteSignature;
use App\Models\Unit;
use App\Models\User;
use App\Services\Camunda\NotaInternaEngine;
use App\Services\Camunda\StartNotaInterna;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class InternalNoteWorkflow
{
    public function __construct(
        private readonly StartNotaInterna $start,
        private readonly NotaInternaEngine $engine,
        private readonly NoteNotices $notices,
    ) {}

    public function save(User $actor, array $data, ?InternalNote $draft = null): InternalNote
    {
        return DB::transaction(function () use ($actor, $data, $draft) {
            $note = $draft ? InternalNote::lockForUpdate()->findOrFail($draft->id) : new InternalNote([
                'author_id' => $actor->id,
                'origin_unit_id' => $actor->unit_id,
                'version' => 0,
                'state' => InternalNote::DRAFT,
            ]);
            abort_unless($note->author_id === $actor->id && $note->origin_unit_id === $actor->unit_id, 403);
            abort_unless($note->state === InternalNote::DRAFT && (! $draft || $note->version === (int) $data['version']), 409);

            $via = array_values(array_map('intval', $data['vias_usuario_ids'] ?? []));
            $cc = array_values(array_map('intval', $data['cc_usuario_ids'] ?? []));
            $this->validateRecipients($actor, (int) $data['destinatario_unidad_id'], $via, $cc);

            $note->fill([
                'recipient_unit_id' => $data['destinatario_unidad_id'],
                'subject' => $data['asunto'],
                'reference' => $data['referencia'] ?? null,
                'body' => $data['cuerpo'],
            ]);
            $participants = $note->exists ? $note->participants()->get()->groupBy('role') : collect();
            if ($note->exists && ! $note->isDirty()
                && $via === ($participants->get('via')?->pluck('user_id')->all() ?? [])
                && $cc === ($participants->get('cc')?->pluck('user_id')->all() ?? [])) {
                return $note;
            }

            $note->fill(['version' => $note->version + 1, 'signature_requested_at' => null])->save();

            $note->participants()->delete();
            foreach (['via' => $via, 'cc' => $cc] as $role => $accounts) {
                foreach ($accounts as $index => $userId) {
                    $note->participants()->create(['role' => $role, 'user_id' => $userId, 'position' => $index + 1]);
                }
            }

            return $note;
        }, 3);
    }

    public function requestSignature(User $actor, InternalNote $note, int $version): InternalNote
    {
        return DB::transaction(function () use ($actor, $note, $version) {
            $current = InternalNote::lockForUpdate()->findOrFail($note->id);
            $this->assertAuthor($actor, $current);
            abort_unless($current->state === InternalNote::DRAFT && $current->version === $version, 409);

            if ($current->signature_requested_at === null && ! $current->senderSignatures()->where('note_version', $version)->exists()) {
                $current->update(['signature_requested_at' => now()]);
            }

            return $current;
        }, 3);
    }

    public function sign(User $actor, InternalNote $note, int $version, string $key, ?array $strokes): InternalNote
    {
        return DB::transaction(function () use ($actor, $note, $version, $key, $strokes) {
            $current = InternalNote::lockForUpdate()->findOrFail($note->id);
            $this->assertAuthor($actor, $current);

            $existing = $current->senderSignatures()->where('user_id', $actor->id)->where('request_key', $key)->first();
            if ($existing !== null) {
                abort_unless($existing->note_version === $version && ($strokes === null || $existing->strokes === $strokes), 409);

                return $current;
            }

            abort_unless($current->state === InternalNote::DRAFT && $current->version === $version && $current->signature_requested_at !== null, 409);
            $this->recordSignature($current, $actor, InternalNoteSignature::SENDER, $version, $key, $strokes);
            $current->update(['signature_requested_at' => null]);

            return $current;
        }, 3);
    }

    public function emit(User $actor, InternalNote $note, int $version, string $key): InternalNote
    {
        $note = DB::transaction(function () use ($actor, $note, $version, $key) {
            $current = InternalNote::lockForUpdate()->findOrFail($note->id);
            $this->assertAuthor($actor, $current);

            if ($current->emission_key !== null) {
                abort_unless($current->emission_key === $key && $current->emission_version === $version, 409);

                return $current;
            }

            abort_unless($current->state === InternalNote::DRAFT && $current->version === $version, 409);
            if (! $current->senderSignatures()->where('user_id', $actor->id)->where('note_version', $version)->exists()) {
                throw ValidationException::withMessages(['firma' => 'La versión vigente debe estar firmada antes de emitir la nota.']);
            }
            $this->validateRecipients($actor, $current->recipient_unit_id, $current->participants()->where('role', 'via')->pluck('user_id')->all(),
                $current->participants()->where('role', 'cc')->pluck('user_id')->all());

            // Serializa la numeración de cada unidad y gestión.
            $unit = Unit::lockForUpdate()->findOrFail($current->origin_unit_id);
            $institutionCode = DB::table('institutions')->where('id', $unit->institution_id)->value('code');
            $year = now('America/La_Paz')->year;
            $sequence = 1 + (int) InternalNote::where('origin_unit_id', $unit->id)->where('cite_year', $year)->max('cite_sequence');

            $current->update([
                'state' => InternalNote::EMITTING,
                'cite' => sprintf('NI/%s/%s/%d/%06d', $institutionCode, $unit->code, $year, $sequence),
                'cite_year' => $year,
                'cite_sequence' => $sequence,
                'emission_key' => $key,
                'emission_version' => $version,
                'document_heading' => $current->documentHeading(),
                'version' => $version + 1,
            ]);

            return $current;
        }, 3);

        if ($note->state !== InternalNote::EMITTING) {
            return $note;
        }

        $reviewers = $note->participants()->where('role', 'via')->pluck('user_id')->map(fn ($id) => (string) $id)->all();
        $instance = $this->fromEngine(fn () => $this->start->execute($note->id, $reviewers));

        if ($instance !== null) {
            DB::transaction(function () use ($note, $reviewers): void {
                $current = InternalNote::lockForUpdate()->findOrFail($note->id);
                if ($current->state !== InternalNote::EMITTING) {
                    return;
                }

                $current->update([
                    'state' => $reviewers === [] ? InternalNote::RECEIVE : InternalNote::REVIEW,
                    'active_position' => $reviewers === [] ? null : 1,
                    'version' => $current->version + 1,
                    'emitted_at' => now(),
                ]);
                $this->notices->forPendingNote($current);
            }, 3);
        }

        return $note->refresh();
    }

    public function approve(User $actor, InternalNote $note, int $version, string $key, ?array $strokes): InternalNote
    {
        $participant = DB::transaction(function () use ($actor, $note, $version, $key, $strokes) {
            $current = InternalNote::lockForUpdate()->findOrFail($note->id);
            $via = $current->participants()->where('role', 'via')->where('user_id', $actor->id)->first();
            abort_if($via === null, 403);
            if ($via->action_key !== null) {
                abort_unless($via->action_key === $key && $via->action_version === $version, 409);
                $existing = $current->signatures()->where('action', InternalNoteSignature::VIA)
                    ->where('user_id', $actor->id)->where('request_key', $key)->first();
                if ($existing !== null) {
                    abort_unless($strokes === null || $existing->strokes === $strokes, 409);
                } elseif ($via->confirmed_at === null) {
                    $this->recordSignature($current, $actor, InternalNoteSignature::VIA, $version, $key, $strokes);
                }

                return $via;
            }

            abort_unless($current->state === InternalNote::REVIEW && $via->position === $current->active_position, 403);
            abort_unless($current->version === $version, 409);
            $this->recordSignature($current, $actor, InternalNoteSignature::VIA, $version, $key, $strokes);
            $via->update(['action_key' => $key, 'action_version' => $version]);

            return $via;
        }, 3);

        if ($participant->confirmed_at !== null) {
            return $note->refresh();
        }

        $instance = DB::table('note_workflow_instances')->where('note_id', $note->id)->value('instance_key');
        abort_unless(is_string($instance), 503, 'No se pudo consultar el proceso. Vuelve a intentar.');
        $confirmed = $this->fromEngine(function () use ($instance, $actor, $participant) {
            if ($participant->task_key === null) {
                $key = $this->engine->activeReviewTask($instance, (string) $actor->id);
                if ($key === null) {
                    return false;
                }

                $participant->newQuery()->whereKey($participant->id)->whereNull('task_key')->update(['task_key' => $key]);
                $participant->refresh();
            }

            return $this->engine->completeReviewTask($participant->task_key);
        });
        if (! $confirmed) {
            return $note->refresh();
        }

        return DB::transaction(function () use ($participant, $note) {
            $current = InternalNote::lockForUpdate()->findOrFail($note->id);
            if ($participant->refresh()->confirmed_at === null) {
                $participant->update(['confirmed_at' => now()]);
                $hasNext = $current->participants()->where('role', 'via')->where('position', $participant->position + 1)->exists();
                $current->update([
                    'state' => $hasNext ? InternalNote::REVIEW : InternalNote::RECEIVE,
                    'active_position' => $hasNext ? $participant->position + 1 : null,
                    'version' => $current->version + 1,
                ]);
                $this->notices->forPendingNote($current);
            }

            return $current;
        }, 3);
    }

    private function assertAuthor(User $actor, InternalNote $note): void
    {
        abort_unless($note->author_id === $actor->id && $note->origin_unit_id === $actor->unit_id, 403);
    }

    private function recordSignature(InternalNote $note, User $actor, string $action, int $version, string $key, ?array $strokes): void
    {
        if ($strokes === null || (! array_is_list($strokes)
            && empty($strokes['strokes']) && empty($strokes['images']['imagen_firma']))) {
            throw ValidationException::withMessages(['firma' => 'Dibuja o carga la firma antes de confirmar.']);
        }

        $note->signatures()->create([
            'user_id' => $actor->id,
            'unit_id' => $actor->unit_id,
            'action' => $action,
            'note_version' => $version,
            'request_key' => $key,
            'strokes' => $strokes,
            'signed_at' => now(),
        ]);
    }

    private function validateRecipients(User $actor, int $destination, array $via, array $cc): void
    {
        $institution = $actor->unit->institution_id;
        $units = Unit::where('institution_id', $institution)->where('enabled', true);
        if (! (clone $units)->whereKey($destination)->exists()) {
            throw ValidationException::withMessages(['destinatario_unidad_id' => 'Selecciona una unidad activa de tu institución.']);
        }

        foreach (['vias_usuario_ids' => $via, 'cc_usuario_ids' => $cc] as $field => $ids) {
            if (User::where('enabled', true)->whereIn('unit_id', (clone $units)->select('id'))->whereIn('id', $ids)->count() !== count($ids)) {
                throw ValidationException::withMessages([$field => 'Selecciona únicamente usuarios activos de tu institución.']);
            }
        }
    }

    private function fromEngine(callable $operation): mixed
    {
        try {
            return $operation();
        } catch (ConnectionException|RequestException) {
            abort(503, 'Camunda no confirmó la operación. Vuelve a intentar con la misma solicitud.');
        }
    }
}
