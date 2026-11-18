<?php

namespace App\Services\Camunda;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use InvalidArgumentException;
use LogicException;
use UnexpectedValueException;

class StartNotaInterna
{
    public function __construct(private readonly NotaInternaEngine $engine) {}

    /**
     * null indica que la emisión está reservada y sigue pendiente de confirmación.
     *
     * @param list<string> $reviewers Identificadores de VÍA en orden.
     */
    public function execute(string $noteId, array $reviewers): ?string
    {
        if (! Str::isUuid($noteId)) {
            throw new InvalidArgumentException('Se requiere el UUID de una nota guardada.');
        }

        if (DB::transactionLevel() !== 0) {
            throw new LogicException('Inicia el flujo después de confirmar la transacción de la nota.');
        }

        $noteId = strtolower($noteId);
        $fingerprint = hash('sha256', json_encode($reviewers, JSON_THROW_ON_ERROR));
        $reserved = DB::table('note_workflow_instances')->insertOrIgnore([
            'note_id' => $noteId,
            'reviewers_fingerprint' => $fingerprint,
        ]);

        $row = DB::table('note_workflow_instances')->where('note_id', $noteId);
        $record = $row->first();
        if ($record === null || ! hash_equals($record->reviewers_fingerprint, $fingerprint)) {
            throw new LogicException('La emisión está reservada con otra secuencia de VÍA o está cambiando.');
        }
        if ($record->instance_key !== null) {
            return $record->instance_key;
        }

        $key = $reserved ? $this->startReservedInstance($noteId, $reviewers) : $this->engine->findInstance($noteId);
        if ($key === null) {
            return $row->value('instance_key');
        }

        (clone $row)->whereNull('instance_key')->update(['instance_key' => $key]);
        $saved = $row->value('instance_key');
        if ($saved !== $key) {
            throw new UnexpectedValueException('La nota tiene una clave de instancia distinta.');
        }

        return $saved;
    }

    /** @param list<string> $reviewers */
    private function startReservedInstance(string $noteId, array $reviewers): ?string
    {
        try {
            return $this->engine->start($noteId, $reviewers);
        } catch (ConnectionException|UnexpectedValueException) {
            return $this->engine->findInstance($noteId);
        } catch (RequestException $error) {
            if (! in_array($error->response->status(), [400, 401, 403, 404], true)) {
                return $this->engine->findInstance($noteId);
            }

            $this->releaseReservation($noteId);

            throw $error;
        } catch (LogicException $error) {
            $this->releaseReservation($noteId);

            throw $error;
        }
    }

    private function releaseReservation(string $noteId): void
    {
        DB::table('note_workflow_instances')->where('note_id', $noteId)->whereNull('instance_key')->delete();
    }
}
