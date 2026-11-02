<?php

namespace App\Services;

use App\Models\Document;
use App\Models\Movement;
use App\Models\User;

class DocumentHistory
{
    public function execute(User $user, string $documentId): array
    {
        abort_unless($user->isOperational(), 403);

        $document = Document::visibleTo($user)->findOrFail($documentId);
        $sheet = $document->sheet()->firstOrFail();

        $movements = $sheet->movements()
            ->with([
                'actor:id,name',
                'originUnit:id,name',
                'destinationUnit:id,name',
            ])
            ->get();

        return [
            'documento_id' => $document->id,
            'hoja' => [
                'id' => $sheet->id,
                'codigo' => $sheet->code,
                'estado' => $sheet->state,
            ],
            'total' => $movements->count(),
            'data' => $movements->map(fn (Movement $movement) => [
                'id' => $movement->id,
                'accion' => $movement->action,
                'actor' => [
                    'id' => $movement->actor_id,
                    'nombre' => $movement->actor?->name,
                ],
                'unidad_origen' => $movement->originUnit === null
                    ? null
                    : [
                        'id' => $movement->origin_unit_id,
                        'nombre' => $movement->originUnit->name,
                    ],
                'unidad_destino' => $movement->destinationUnit === null
                    ? null
                    : [
                        'id' => $movement->destination_unit_id,
                        'nombre' => $movement->destinationUnit->name,
                    ],
                'fecha' => $movement->occurred_at->toISOString(),
                'estado_resultante' => $movement->resulting_state,
                'motivo' => $movement->reason,
            ])->values()->all(),
        ];
    }
}
