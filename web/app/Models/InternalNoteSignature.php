<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class InternalNoteSignature extends Model
{
    public const SENDER = 'firma_remitente';

    public const VIA = 'conformidad_via';

    public $timestamps = false;

    protected $guarded = [];

    protected $hidden = ['strokes', 'request_key'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function unit(): BelongsTo
    {
        return $this->belongsTo(Unit::class);
    }

    protected function casts(): array
    {
        return ['user_id' => 'integer', 'unit_id' => 'integer', 'note_version' => 'integer', 'strokes' => 'encrypted:array', 'signed_at' => 'datetime'];
    }
}
