<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Unit extends Model
{
    protected $fillable = ['institution_id', 'code', 'name', 'enabled'];

    protected function casts(): array
    {
        return ['enabled' => 'boolean'];
    }
}
