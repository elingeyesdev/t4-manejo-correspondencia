<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Catalog extends Model
{
    protected $fillable = ['kind', 'code', 'name', 'enabled'];

    protected function casts(): array
    {
        return ['enabled' => 'boolean'];
    }
}
