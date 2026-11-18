<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('internal_notes', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('author_id')->constrained('users')->restrictOnDelete();
            $table->foreignId('origin_unit_id')->constrained('units')->restrictOnDelete();
            $table->foreignId('recipient_unit_id')->constrained('units')->restrictOnDelete();
            $table->string('subject', 200);
            $table->string('reference', 200)->nullable();
            $table->text('body');
            $table->string('state', 30)->default('borrador');
            $table->unsignedInteger('version')->default(1);
            $table->unsignedInteger('active_position')->nullable();
            $table->string('cite', 120)->nullable()->unique();
            $table->unsignedSmallInteger('cite_year')->nullable();
            $table->unsignedInteger('cite_sequence')->nullable();
            $table->uuid('emission_key')->nullable();
            $table->unsignedInteger('emission_version')->nullable();
            $table->timestamp('emitted_at')->nullable();
            $table->timestamps();
            $table->unique(['origin_unit_id', 'cite_year', 'cite_sequence']);
            $table->index(['recipient_unit_id', 'state']);
        });

        Schema::create('internal_note_participants', function (Blueprint $table): void {
            $table->id();
            $table->foreignUuid('note_id')->constrained('internal_notes')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->string('role', 10);
            $table->unsignedInteger('position');
            $table->uuid('action_key')->nullable();
            $table->unsignedInteger('action_version')->nullable();
            $table->string('task_key', 32)->nullable();
            $table->timestamp('confirmed_at')->nullable();
            $table->unique(['note_id', 'role', 'position']);
            $table->unique(['note_id', 'role', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('internal_note_participants');
        Schema::dropIfExists('internal_notes');
    }
};
