<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NoteNoticeDevice extends Model
{
    public $incrementing = false;

    public $timestamps = false;

    protected $keyType = 'string';

    protected $guarded = [];

    protected $hidden = ['fcm_token', 'token_hash'];

    protected function casts(): array
    {
        return ['fcm_token' => 'encrypted'];
    }
}
