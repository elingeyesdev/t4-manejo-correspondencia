<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Attachment extends Model
{
    use HasUuids;

    protected $fillable = [
        'document_id',
        'original_name',
        'mime_type',
        'size_bytes',
        'storage_path',
        'key_version',
    ];

    protected $hidden = [
        'storage_path',
        'key_version',
    ];

    protected function casts(): array
    {
        return [
            'size_bytes' => 'integer',
        ];
    }

    public function document(): BelongsTo
    {
        return $this->belongsTo(Document::class);
    }
}
