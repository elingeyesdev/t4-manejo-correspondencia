<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NoteNotice extends Model
{
    use HasUuids;

    public const REVIEW = 'revision_via_pendiente';

    public const INITIAL_RECEIPT = 'recepcion_inicial_pendiente';

    public const DERIVED_RECEIPT = 'recepcion_derivacion_pendiente';

    public $timestamps = false;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['created_at' => 'datetime', 'read_at' => 'datetime', 'event_version' => 'integer'];
    }

    public function note(): BelongsTo
    {
        return $this->belongsTo(InternalNote::class, 'note_id');
    }

    public function scopeVisibleTo(Builder $query, User $actor): Builder
    {
        return $query->where('user_id', $actor->id)
            ->whereHas('note', fn (Builder $notes) => $notes->visibleTo($actor));
    }

    public function label(): string
    {
        return match ($this->type) {
            self::REVIEW => 'Revisión VÍA pendiente',
            self::INITIAL_RECEIPT => 'Recepción inicial pendiente',
            self::DERIVED_RECEIPT => 'Recepción por derivación pendiente',
        };
    }
}
