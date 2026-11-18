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
    private const RETRY_DELAY_SECONDS = 2;

    public function __construct(private readonly NotaInternaEngine $engine) {}

    /**
     * null indica que la emisi├│n est├í reservada y sigue pendiente de confirmaci├│n.
     *
     * @param  list<string>  $reviewers  Identificadores de V├ìA en orden.
     */
    public function execute(string $noteId, array $reviewers): ?string
    {
        if (! Str::isUuid($noteId)) {
            throw new InvalidArgumentException('Se requiere el UUID de una nota guardada.');
        }

        if (DB::transactionLevel() !== 0) {
            throw new LogicException('Inicia el flujo despu├⌐s de confirmar la transacci├│n de la nota.');
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
            throw new LogicException('La emisi├│n est├í reservada con otra secuencia de V├ìA o est├í cambiando.');
        }
        if ($record->instance_key !== null) {
            return $record->instance_key;
        }

        if ($record->retry_at !== null) {
            // Solo el primer solicitante que reclama el intento puede volver a crear.
            $reserved = (clone $row)->whereNull('instance_key')
                ->where('retry_at', '<=', now())
                ->update(['retry_at' => null]);

            if (! $reserved) {
                return $row->value('instance_key');
            }
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
            $title = $error->response->json('title');
            if ($error->response->status() === 503 && is_string($title) && str_contains($title, 'RESOURCE_EXHAUSTED')) {
                DB::table('note_workflow_instances')->where('note_id', $noteId)->whereNull('instance_key')
                    ->update(['retry_at' => now()->addSeconds(self::RETRY_DELAY_SECONDS)]);

                return null;
            }

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
