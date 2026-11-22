<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InternalNoteSignature extends Model
{
    public const SENDER = 'firma_remitente';

    public const VIA = 'conformidad_via';

    public $timestamps = false;

    protected $guarded = [];

    protected $hidden = ['strokes', 'request_key'];

    protected function casts(): array
    {
        return ['note_version' => 'integer', 'strokes' => 'encrypted:array', 'signed_at' => 'datetime'];
    }
}
