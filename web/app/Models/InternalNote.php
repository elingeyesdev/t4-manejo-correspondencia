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

    public const RECEIVED = 'recibida';

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
            'signature_requested_at' => 'datetime',
            'active_position' => 'integer',
            'receipt_actor_id' => 'integer',
            'receipt_version' => 'integer',
        ];
    }

    public function stateLabel(): string
    {
        return match ($this->displayState()) {
            self::DRAFT => 'Borrador',
            self::EMITTING => 'Emisión pendiente',
            self::REVIEW => 'Pendiente de revisión',
            self::RECEIVE => 'Pendiente de recepción',
            self::RECEIVED => 'Recibida',
            'en_atencion' => 'En atención',
            'cerrada' => 'Cerrada',
        };
    }

    public function displayState(): string
    {
        return match ($this->document?->sheet?->state) {
            'PENDIENTE_RECEPCION' => self::RECEIVE,
            'EN_ATENCION' => 'en_atencion',
            'CERRADA' => 'cerrada',
            default => $this->state,
        };
    }

    public function allowsInitialReceipt(User $actor): bool
    {
        return $actor->isOperational() && $actor->role === 'funcionario'
            && $this->recipient_unit_id === (int) $actor->unit_id
            && ($this->receipt_actor_id === null || $this->receipt_actor_id === (int) $actor->id);
    }

    public function document(): BelongsTo
    {
        return $this->belongsTo(Document::class);
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

    public function signatures(): HasMany
    {
        return $this->hasMany(InternalNoteSignature::class, 'note_id');
    }

    public function senderSignatures(): HasMany
    {
        return $this->signatures()->where('action', InternalNoteSignature::SENDER);
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
                        $delivered->whereIn('state', [self::RECEIVE, self::RECEIVED])
                            ->where(fn (Builder $recipient) => $recipient->where('recipient_unit_id', $actor->unit_id)
                                ->orWhereHas('participants', fn (Builder $copy) => $copy->where('role', 'cc')->where('user_id', $actor->id)));
                    })->orWhereHas('document', fn (Builder $documents) => $documents->visibleTo($actor));
            });
    }
}
