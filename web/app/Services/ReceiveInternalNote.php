<?php

namespace App\Services;

use App\Models\Catalog;
use App\Models\Document;
use App\Models\InternalNote;
use App\Models\Unit;
use App\Models\User;
use App\Services\Camunda\NotaInternaEngine;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class ReceiveInternalNote
{
    public function __construct(private readonly NotaInternaEngine $engine) {}

    public function execute(User $actor, InternalNote $note, int $version, string $key): InternalNote
    {
        $note = DB::transaction(function () use ($actor, $note, $version, $key) {
            $actor = User::lockForUpdate()->findOrFail($actor->id);
            $current = InternalNote::lockForUpdate()->findOrFail($note->id);
            abort_unless($current->allowsInitialReceipt($actor), 403, 'ACCION_NO_PERMITIDA');

            if ($current->receipt_key !== null) {
                abort_unless($current->receipt_key === $key && $current->receipt_version === $version, 409, 'CLAVE_REUTILIZADA');

                return $current;
            }

            abort_unless($current->state === InternalNote::RECEIVE, 409, 'ESTADO_INCOMPATIBLE');
            abort_unless($current->version === $version, 409, 'VERSION_DESACTUALIZADA');
            abort_if(InternalNote::where('receipt_actor_id', $actor->id)->where('receipt_key', $key)->exists(), 409, 'CLAVE_REUTILIZADA');
            $current->update(['receipt_key' => $key, 'receipt_version' => $version, 'receipt_actor_id' => $actor->id]);

            return $current;
        }, 3);

        if ($note->document_id !== null) {
            return $note->refresh();
        }

        $confirmed = $this->confirmInCamunda($note);
        $receipt = DB::transaction(function () use ($note, $actor, $key, $confirmed): ?InternalNote {
            $actor = User::lockForUpdate()->findOrFail($actor->id);
            $current = InternalNote::lockForUpdate()->findOrFail($note->id);
            abort_unless($current->receipt_actor_id === (int) $actor->id
                && $current->receipt_key === $key, 403, 'ACCION_NO_PERMITIDA');

            $actor->setRelation('unit', Unit::whereKey($actor->unit_id)->lockForUpdate()->first());
            if (! $current->allowsInitialReceipt($actor)) {
                if ($current->document_id === null) {
                    // Conserva la tarea de Camunda para que otro receptor autorizado pueda conciliarla.
                    $current->update(['receipt_key' => null, 'receipt_version' => null, 'receipt_actor_id' => null]);
                }

                return null;
            }

            if ($current->document_id !== null || ! $confirmed) {
                return $current;
            }

            $type = Catalog::firstOrCreate(['kind' => 'tipo', 'code' => 'NOTA_INTERNA'], ['name' => 'Nota Interna']);
            $priority = Catalog::firstOrCreate(['kind' => 'prioridad', 'code' => 'NORMAL'], ['name' => 'Normal']);
            $instant = now();
            $identifier = $instant->year.'-'.Str::ulid();
            $document = Document::create([
                'id' => (string) Str::uuid(),
                'code' => $current->cite,
                'guide' => 'COR-'.$identifier,
                'sender' => $current->author->name,
                'subject' => $current->subject,
                'received_on' => $instant->copy()->timezone('America/La_Paz')->toDateString(),
                'type_id' => $type->id,
                'priority_id' => $priority->id,
                'unit_id' => $current->recipient_unit_id,
                'created_by' => $actor->id,
            ]);
            $sheet = $document->sheet()->create([
                'id' => (string) Str::uuid(),
                'code' => 'HR-'.$identifier,
                'state' => 'RECIBIDA',
                'responsible_id' => $actor->id,
                'current_unit_id' => $current->recipient_unit_id,
                'version' => 1,
            ]);
            $sheet->movements()->create([
                'id' => (string) Str::uuid(),
                'actor_id' => $actor->id,
                'origin_unit_id' => $current->origin_unit_id,
                'destination_unit_id' => $current->recipient_unit_id,
                'action' => 'RECEPCION',
                'resulting_state' => $sheet->state,
                'sheet_version' => 1,
                'occurred_at' => $instant,
            ]);
            $current->update([
                'document_id' => $document->id,
                'state' => InternalNote::RECEIVED,
                'version' => $current->version + 1,
            ]);

            return $current;
        }, 3);

        abort_unless($receipt !== null, 403, 'ACCION_NO_PERMITIDA');

        return $receipt;
    }

    private function confirmInCamunda(InternalNote $note): bool
    {
        $instance = DB::table('note_workflow_instances')->where('note_id', $note->id)->value('instance_key');
        abort_unless(is_string($instance), 503, 'No se pudo consultar el proceso. Vuelve a intentar.');

        try {
            if ($note->receipt_task_key === null) {
                $key = $this->engine->activeTask($instance, 'RecibirNota');
                if ($key === null) {
                    return false;
                }

                InternalNote::whereKey($note->id)->whereNull('receipt_task_key')->update(['receipt_task_key' => $key]);
                $note->refresh();
            }

            return $this->engine->completeTask($note->receipt_task_key);
        } catch (ConnectionException|RequestException) {
            return false;
        }
    }
}
