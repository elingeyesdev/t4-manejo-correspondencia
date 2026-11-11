<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class RouteSheet extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    public function movements()
    {
        return $this->hasMany(Movement::class)->orderBy('sheet_version');
    }

    public function document()
    {
        return $this->belongsTo(Document::class);
    }

    public function currentUnit()
    {
        return $this->belongsTo(Unit::class, 'current_unit_id');
    }

    public function pendingUnit()
    {
        return $this->belongsTo(Unit::class, 'pending_unit_id');
    }

    public function responsible()
    {
        return $this->belongsTo(User::class, 'responsible_id');
    }

    public function scopeVisibleTo(Builder $query, User $actor): Builder
    {
        return $query->whereHas('document', fn (Builder $documents) => $documents->visibleTo($actor));
    }

    public function isResponsible(User $actor): bool
    {
        return (int) $this->responsible_id === (int) $actor->id
            && (int) $this->current_unit_id === (int) $actor->unit_id;
    }

    public function canDerive(User $actor): bool
    {
        return $this->isResponsible($actor)
            && in_array($this->state, ['REGISTRADA', 'RECIBIDA', 'EN_ATENCION'], true);
    }

    public function canReceive(User $actor): bool
    {
        return $this->state === 'PENDIENTE_RECEPCION'
            && $this->pending_unit_id !== null
            && $actor->role === 'funcionario'
            && (int) $actor->unit_id === (int) $this->pending_unit_id;
    }

    public function canAttend(User $actor): bool
    {
        return $this->isResponsible($actor)
            && in_array($this->state, ['RECIBIDA', 'EN_ATENCION'], true);
    }

    public function canUploadAttachment(User $actor): bool
    {
        return $this->state !== 'CERRADA' && ($actor->canRegister() || $this->canAttend($actor));
    }

    public function eligibleDestinations(): Builder
    {
        return Unit::query()
            ->where('institution_id', $this->document->unit->institution_id)
            ->where('enabled', true)
            ->where('id', '!=', $this->current_unit_id);
    }
}
