<?php

namespace App\Services;

use App\Models\Catalog;
use App\Models\Document;
use App\Models\RouteSheet;
use App\Models\Unit;
use App\Models\User;
use Carbon\CarbonInterface;
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

    public function attend(User $actor, string $sheetId, array $data): array
    {
        return $this->transition($actor, $sheetId, 'atencion', $data['request_key'], [
            'version' => (int) $data['version'],
            'observacion' => $data['observacion'],
        ]);
    }

    public function respond(User $actor, string $documentId, array $data): array
    {
        $sheet = RouteSheet::query()->where('document_id', $documentId)->firstOrFail(['id']);

        return $this->transition($actor, $sheet->id, 'respuesta', $data['request_key'], [
            'version' => (int) $data['version'],
            'remitente' => $data['remitente'],
            'asunto' => $data['asunto'],
            'fecha' => $data['fecha'],
            'tipo_id' => (int) $data['tipo_id'],
            'prioridad_id' => (int) $data['prioridad_id'],
        ]);
    }

    public function close(User $actor, string $sheetId, array $data): array
    {
        return $this->transition($actor, $sheetId, 'cierre', $data['request_key'], [
            'version' => (int) $data['version'],
            'motivo' => trim($data['motivo'], " \t\r\n"),
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

            if ($operation === 'cierre') {
                abort_unless($sheet->isResponsible($actor), 403, 'ACCION_NO_PERMITIDA');
            }

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

            if ($operation === 'cierre' && $sheet->state === 'CERRADA') {
                $closure = DB::table('requests')->where([
                    'actor_id' => $actor->id,
                    'document_id' => $document->id,
                    'operation' => 'cierre',
                ])->orderBy('id')->first();
                abort_unless($closure, 409, 'ESTADO_INCOMPATIBLE');

                $payload = json_decode($closure->response_payload, true, 512, JSON_THROW_ON_ERROR);
                $this->saveResult($request, $fingerprint, $document->id, $payload, now());

                return [$payload, false];
            }

            abort_unless((int) $sheet->version === $intent['version'], 409, 'VERSION_DESACTUALIZADA');

            $originUnitId = (int) $sheet->current_unit_id;
            $destinationUnitId = match ($operation) {
                'derivacion' => $this->applyDerivation($actor, $sheet, $intent),
                'recepcion' => $this->applyReception($actor, $sheet),
                'atencion' => $this->applyAttention($actor, $sheet),
                'respuesta' => $originUnitId,
                'cierre' => $this->applyClosure($actor, $sheet),
            };

            $instant = now();
            $response = $operation === 'respuesta' ? $this->createResponse($actor, $sheet, $intent, $instant) : null;
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
                'reason' => $response
                    ? 'Respuesta vinculada: '.$response->code
                    : ($intent['motivo'] ?? $intent['observacion'] ?? null),
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

            if ($response !== null) {
                $payload['respuesta_id'] = $response->id;
            }

            if ($operation === 'cierre') {
                $payload['movimiento']['motivo'] = $movement->reason;
            }

            $this->saveResult($request, $fingerprint, $document->id, $payload, $instant);

            return [$payload, true];
        }, 3);
    }

    private function saveResult(array $request, string $fingerprint, string $documentId, array $payload, CarbonInterface $instant): void
    {
        DB::table('requests')->insert($request + [
            'fingerprint' => $fingerprint,
            'document_id' => $documentId,
            'response_payload' => json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR),
            'created_at' => $instant,
        ]);
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

    private function applyAttention(User $actor, RouteSheet $sheet): int
    {
        abort_unless($sheet->isResponsible($actor), 403, 'ACCION_NO_PERMITIDA');
        abort_unless($sheet->canAttend($actor), 409, 'ESTADO_INCOMPATIBLE');

        $sheet->state = 'EN_ATENCION';

        return (int) $sheet->current_unit_id;
    }

    private function createResponse(User $actor, RouteSheet $sheet, array $intent, CarbonInterface $instant): Document
    {
        abort_unless($sheet->isResponsible($actor), 403, 'ACCION_NO_PERMITIDA');
        abort_unless($sheet->canAttend($actor) && $sheet->pending_unit_id === null, 409, 'ESTADO_INCOMPATIBLE');

        foreach (['tipo_id' => 'tipo', 'prioridad_id' => 'prioridad'] as $field => $kind) {
            $catalog = Catalog::query()
                ->whereKey($intent[$field])
                ->where('kind', $kind)
                ->where('enabled', true)
                ->lockForUpdate()
                ->first();

            if ($catalog === null) {
                throw ValidationException::withMessages([$field => 'Selecciona una opción habilitada.']);
            }
        }

        $suffix = $instant->year.'-'.Str::ulid();

        return $sheet->document->responses()->create([
            'id' => (string) Str::uuid(),
            'code' => 'DOC-'.$suffix,
            'guide' => 'COR-'.$suffix,
            'sender' => $intent['remitente'],
            'subject' => $intent['asunto'],
            'received_on' => $intent['fecha'],
            'type_id' => $intent['tipo_id'],
            'priority_id' => $intent['prioridad_id'],
            'unit_id' => $sheet->current_unit_id,
            'created_by' => $actor->id,
        ]);
    }

    private function applyClosure(User $actor, RouteSheet $sheet): int
    {
        abort_unless($sheet->canAttend($actor) && $sheet->pending_unit_id === null, 409, 'ESTADO_INCOMPATIBLE');

        $sheet->state = 'CERRADA';

        return (int) $sheet->current_unit_id;
    }
}
