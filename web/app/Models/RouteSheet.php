<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RouteSheet extends Model
{
    public $incrementing = false;

    protected $keyType = 'string';

    protected $guarded = [];

    public function movements()
    {
        return $this->hasMany(Movement::class)->orderBy('occurred_at')->orderBy('id');
    }
}
