<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Document extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    protected function casts(): array
    {
        return ['received_on' => 'date'];
    }

    public function sheet()
    {
        return $this->hasOne(RouteSheet::class);
    }

    public function original(): BelongsTo
    {
        return $this->belongsTo(self::class, 'response_to_id');
    }

    public function responses(): HasMany
    {
        return $this->hasMany(self::class, 'response_to_id');
    }

    public function rootDocument(): self
    {
        return $this->getRelationValue('original') ?? $this;
    }

    public function unit()
    {
        return $this->belongsTo(Unit::class);
    }

    public function type()
    {
        return $this->belongsTo(Catalog::class, 'type_id');
    }

    public function priority()
    {
        return $this->belongsTo(Catalog::class, 'priority_id');
    }

    public function scopeVisibleTo(Builder $q, User $user): Builder
    {
        if ($user->isAdmin()) {
            return $q;
        }

        $visibleOriginal = function (Builder $original) use ($user): void {
            $original->whereNull('response_to_id')
                ->where(function (Builder $documents) use ($user): void {
                    $documents->where('unit_id', $user->unit_id)
                        ->orWhereHas('sheet', function (Builder $sheets) use ($user): void {
                            $sheets->where('responsible_id', $user->id);

                            if ($user->role === 'funcionario') {
                                $sheets->orWhere(function (Builder $pending) use ($user): void {
                                    $pending->where('state', 'PENDIENTE_RECEPCION')
                                        ->where('pending_unit_id', $user->unit_id);
                                });
                            }
                        });
                });
        };

        return $q->where(function (Builder $documents) use ($visibleOriginal): void {
            $documents->where($visibleOriginal)->orWhereHas('original', $visibleOriginal);
        });
    }

    public function detailPayload(User $actor): array
    {
        $payload = $this->payload();
        $original = $this->rootDocument();
        $original->loadMissing('sheet.currentUnit', 'sheet.responsible');
        $sheet = $original->sheet;

        $payload['hoja']['unidad_vigente_id'] = $sheet->current_unit_id;
        $payload['hoja']['unidad_vigente'] = [
            'id' => $sheet->currentUnit->id,
            'nombre' => $sheet->currentUnit->name,
        ];
        $payload['hoja']['responsable'] = [
            'id' => $sheet->responsible->id,
            'nombre' => $sheet->responsible->name,
        ];
        $payload['acciones_permitidas'] = match (true) {
            $this->response_to_id !== null => [],
            $sheet->canAttend($actor) && $sheet->pending_unit_id === null => ['derivar', 'atender', 'responder', 'cerrar'],
            $sheet->canAttend($actor) => ['derivar', 'atender'],
            $sheet->canDerive($actor) => ['derivar'],
            $sheet->canReceive($actor) => ['recibir'],
            default => [],
        };

        $payload['documento_original'] = $this->response_to_id === null ? null : $original->summary();
        $payload['respuestas'] = $this->response_to_id !== null ? [] : $this->responses()
            ->orderBy('created_at')
            ->orderBy('id')
            ->get(['id', 'code', 'subject'])
            ->map(fn (Document $response) => $response->summary())->all();

        return $payload;
    }

    public function payload(): array
    {
        $original = $this->rootDocument();
        $original->loadMissing('sheet.movements');
        $sheet = $original->sheet;
        $this->loadMissing('unit', 'type', 'priority');

        return ['id' => $this->id, 'codigo' => $this->code, 'guia' => $this->guide,
            'remitente' => $this->sender, 'asunto' => $this->subject, 'fecha' => $this->received_on->format('Y-m-d'),
            'unidad' => $this->unit, 'tipo' => $this->type, 'prioridad' => $this->priority,
            'estado' => $sheet->state, 'fechaUltimoMovimiento' => $sheet->movements->last()?->occurred_at->toISOString(),
            'hoja' => ['id' => $sheet->id, 'codigo' => $sheet->code, 'responsable_id' => $sheet->responsible_id,
                'destino_pendiente_id' => $sheet->pending_unit_id, 'version' => $sheet->version],
            'movimientos' => $sheet->movements];
    }

    private function summary(): array
    {
        return ['id' => $this->id, 'codigo' => $this->code, 'asunto' => $this->subject];
    }
}
