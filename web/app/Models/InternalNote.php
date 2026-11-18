<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class InternalNote extends Model
{
    use HasUuids;

    public const DRAFT = 'borrador';

    public const EMITTING = 'emision_pendiente';

    public const REVIEW = 'pendiente_revision';

    public const RECEIVE = 'pendiente_recepcion';

    protected $guarded = [];

    protected function casts(): array
    {
        return [
            'author_id' => 'integer',
            'origin_unit_id' => 'integer',
            'recipient_unit_id' => 'integer',
            'version' => 'integer',
            'emission_version' => 'integer',
            'emitted_at' => 'datetime',
            'active_position' => 'integer',
        ];
    }

    public function stateLabel(): string
    {
        return match ($this->state) {
            self::DRAFT => 'Borrador',
            self::EMITTING => 'Emisi├│n pendiente',
            self::REVIEW => 'Pendiente de revisi├│n',
            self::RECEIVE => 'Pendiente de recepci├│n',
        };
    }

    public function origin(): BelongsTo
    {
        return $this->belongsTo(Unit::class, 'origin_unit_id');
    }

    public function recipient(): BelongsTo
    {
        return $this->belongsTo(Unit::class, 'recipient_unit_id');
    }

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function participants(): HasMany
    {
        return $this->hasMany(InternalNoteParticipant::class, 'note_id')->orderBy('position');
    }

    public function scopeVisibleTo(Builder $query, User $actor): Builder
    {
        return $query->whereHas('origin', fn (Builder $origin) => $origin->where('institution_id', $actor->unit->institution_id))
            ->where(function (Builder $visible) use ($actor): void {
                $visible->where('author_id', $actor->id)
                    ->orWhere(function (Builder $review) use ($actor): void {
                        $review->whereHas('participants', function (Builder $via) use ($actor): void {
                            $via->where('role', 'via')->where('user_id', $actor->id)
                                ->where(fn (Builder $eligible) => $eligible->whereColumn('position', 'internal_notes.active_position')->orWhereNotNull('confirmed_at'));
                        });
                    })
                    ->orWhere(function (Builder $delivered) use ($actor): void {
                        $delivered->where('state', self::RECEIVE)
                            ->where(fn (Builder $recipient) => $recipient->where('recipient_unit_id', $actor->unit_id)
                                ->orWhereHas('participants', fn (Builder $copy) => $copy->where('role', 'cc')->where('user_id', $actor->id)));
                    });
            });
    }
}
