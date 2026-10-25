<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = ['name', 'email', 'password', 'unit_id', 'role', 'enabled'];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return ['password' => 'hashed', 'enabled' => 'boolean', 'email_verified_at' => 'datetime'];
    }

    public function unit()
    {
        return $this->belongsTo(Unit::class);
    }

    public function isAdmin(): bool
    {
        return $this->role === 'administrador';
    }

    public function canRegister(): bool
    {
        return in_array($this->role, ['administrador', 'recepcion']);
    }

    public function isOperational(): bool
    {
        return $this->enabled && $this->unit?->enabled;
    }
}
