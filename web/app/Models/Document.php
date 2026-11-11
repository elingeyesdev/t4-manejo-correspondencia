<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

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

        return $q->where(function (Builder $documents) use ($user): void {
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
    }

    public function detailPayload(User $actor): array
    {
        $payload = $this->payload();
        $this->loadMissing('sheet.currentUnit', 'sheet.responsible');
        $sheet = $this->sheet;

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
            $sheet->canAttend($actor) => ['derivar', 'atender'],
            $sheet->canDerive($actor) => ['derivar'],
            $sheet->canReceive($actor) => ['recibir'],
            default => [],
        };

        return $payload;
    }

    public function payload(): array
    {
        $this->loadMissing('sheet.movements', 'unit', 'type', 'priority');

        return ['id' => $this->id, 'codigo' => $this->code, 'guia' => $this->guide,
            'remitente' => $this->sender, 'asunto' => $this->subject, 'fecha' => $this->received_on->format('Y-m-d'),
            'unidad' => $this->unit, 'tipo' => $this->type, 'prioridad' => $this->priority,
            'estado' => $this->sheet->state, 'fechaUltimoMovimiento' => $this->sheet->movements->last()?->occurred_at->toISOString(),
            'hoja' => ['id' => $this->sheet->id, 'codigo' => $this->sheet->code, 'responsable_id' => $this->sheet->responsible_id,
                'destino_pendiente_id' => $this->sheet->pending_unit_id, 'version' => $this->sheet->version],
            'movimientos' => $this->sheet->movements];
    }
}
