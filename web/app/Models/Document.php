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
        return $user->isAdmin() ? $q : $q->where('unit_id', $user->unit_id);
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
