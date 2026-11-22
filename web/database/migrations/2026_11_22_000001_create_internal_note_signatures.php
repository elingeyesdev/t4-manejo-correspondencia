<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('internal_notes', function (Blueprint $table): void {
            $table->timestamp('signature_requested_at')->nullable();
        });

        Schema::create('internal_note_signatures', function (Blueprint $table): void {
            $table->id();
            $table->foreignUuid('note_id')->constrained('internal_notes')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->foreignId('unit_id')->constrained()->restrictOnDelete();
            $table->string('action', 24);
            $table->unsignedInteger('note_version');
            $table->uuid('request_key');
            $table->text('strokes');
            $table->timestamp('signed_at');
            $table->unique(['note_id', 'action', 'user_id', 'note_version'], 'note_signatures_version_unique');
            $table->unique(['note_id', 'action', 'user_id', 'request_key'], 'note_signatures_request_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('internal_note_signatures');

        Schema::table('internal_notes', function (Blueprint $table): void {
            $table->dropColumn('signature_requested_at');
        });
    }
};
