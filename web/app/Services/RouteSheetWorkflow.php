<?php

namespace App\Services;

use App\Models\Document;
use App\Models\RouteSheet;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class RouteSheetWorkflow
{
    public function derive(User $actor, string $sheetId, array $data): array
    {
        return $this->transition($actor, $sheetId, 'derivacion', $data['request_key'], [
            'version' => (int) $data['version'],
            'destino_unidad_id' => (int) $data['destino_unidad_id'],
            'motivo' => trim($data['motivo'], " \t\r\n"),
        ]);
    }

    public function receive(User $actor, string $sheetId, array $data): array
    {
        return $this->transition($actor, $sheetId, 'recepcion', $data['request_key'], [
            'version' => (int) $data['version'],
        ]);
    }

    private function transition(
        User $actor,
        string $sheetId,
        string $operation,
        string $requestKey,
        array $intent,
    ): array {
        $fingerprint = hash('sha256', json_encode(
            ['hoja_id' => $sheetId] + $intent,
            JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR,
        ));

        return DB::transaction(function () use ($actor, $sheetId, $operation, $requestKey, $intent, $fingerprint): array {
            // El bloqueo del actor serializa la misma clave incluso si se intenta usar en otra hoja.
            $actor = User::query()->lockForUpdate()->findOrFail($actor->id);
            abort_unless($actor->isOperational(), 403, 'ACCION_NO_PERMITIDA');

            $sheet = RouteSheet::query()->lockForUpdate()->findOrFail($sheetId);
            $document = Document::visibleTo($actor)->findOrFail($sheet->document_id);
            $sheet->setRelation('document', $document);

            $request = [
                'actor_id' => $actor->id,
                'operation' => $operation,
                'key' => $requestKey,
            ];
            $previous = DB::table('requests')->where($request)->first();

            if ($previous) {
                abort_unless(hash_equals($previous->fingerprint, $fingerprint), 409, 'CLAVE_REUTILIZADA');

                return [json_decode($previous->response_payload, true, 512, JSON_THROW_ON_ERROR), false];
            }

            abort_unless((int) $sheet->version === $intent['version'], 409, 'VERSION_DESACTUALIZADA');

            $originUnitId = (int) $sheet->current_unit_id;
            $destinationUnitId = match ($operation) {
                'derivacion' => $this->applyDerivation($actor, $sheet, $intent),
                'recepcion' => $this->applyReception($actor, $sheet),
            };

            $instant = now();
            $sheet->version = $intent['version'] + 1;
            $sheet->save();

            $movement = $sheet->movements()->create([
                'id' => (string) Str::uuid(),
                'actor_id' => $actor->id,
                'origin_unit_id' => $originUnitId,
                'destination_unit_id' => $destinationUnitId,
                'action' => strtoupper($operation),
                'resulting_state' => $sheet->state,
                'sheet_version' => $sheet->version,
                'reason' => $intent['motivo'] ?? null,
                'occurred_at' => $instant,
            ]);

            $payload = [
                'documento_id' => $document->id,
                'hoja' => [
                    'id' => $sheet->id,
                    'estado' => $sheet->state,
                    'version' => $sheet->version,
                    'responsable_id' => $sheet->responsible_id,
                    'unidad_vigente_id' => $sheet->current_unit_id,
                    'destino_pendiente_id' => $sheet->pending_unit_id,
                ],
                'movimiento' => [
                    'id' => $movement->id,
                    'accion' => $movement->action,
                    'actor_id' => $actor->id,
                    'unidad_origen_id' => $originUnitId,
                    'unidad_destino_id' => $destinationUnitId,
                    'fecha' => $instant->toISOString(),
                ],
            ];

            DB::table('requests')->insert($request + [
                'fingerprint' => $fingerprint,
                'document_id' => $document->id,
                'response_payload' => json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR),
                'created_at' => $instant,
            ]);

            return [$payload, true];
        }, 3);
    }

    private function applyDerivation(User $actor, RouteSheet $sheet, array $intent): int
    {
        abort_unless($sheet->isResponsible($actor), 403, 'ACCION_NO_PERMITIDA');
        abort_unless($sheet->canDerive($actor), 409, 'ESTADO_INCOMPATIBLE');

        if ($intent['motivo'] === '' || mb_strlen($intent['motivo'], 'UTF-8') > 500) {
            throw ValidationException::withMessages([
                'motivo' => 'El motivo debe tener entre 1 y 500 caracteres.',
            ]);
        }

        $destination = $sheet->eligibleDestinations()
            ->whereKey($intent['destino_unidad_id'])
            ->lockForUpdate()
            ->first();

        if (! $destination) {
            throw ValidationException::withMessages([
                'destino_unidad_id' => 'Selecciona una unidad habilitada distinta de la unidad vigente.',
            ]);
        }

        $sheet->fill([
            'state' => 'PENDIENTE_RECEPCION',
            'pending_unit_id' => $destination->id,
        ]);

        return (int) $destination->id;
    }

    private function applyReception(User $actor, RouteSheet $sheet): int
    {
        abort_unless(
            $sheet->state === 'PENDIENTE_RECEPCION' && $sheet->pending_unit_id !== null,
            409,
            'ESTADO_INCOMPATIBLE',
        );

        $destinationUnitId = (int) $sheet->pending_unit_id;
        abort_unless($sheet->canReceive($actor), 403, 'ACCION_NO_PERMITIDA');

        $unit = Unit::query()->whereKey($destinationUnitId)->lockForUpdate()->first();
        abort_unless($unit?->enabled, 403, 'ACCION_NO_PERMITIDA');

        $sheet->fill([
            'state' => 'RECIBIDA',
            'responsible_id' => $actor->id,
            'current_unit_id' => $destinationUnitId,
            'pending_unit_id' => null,
        ]);

        return $destinationUnitId;
    }
}
