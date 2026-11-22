<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('note_notice_devices', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('access_token_id')->nullable()->constrained('personal_access_tokens')->nullOnDelete();
            $table->char('token_hash', 64)->unique();
            $table->text('fcm_token');
        });

        Schema::create('note_notices', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('note_id')->constrained('internal_notes')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('type', 40);
            $table->string('event_key', 64);
            $table->unsignedInteger('event_version');
            $table->timestamp('created_at');
            $table->timestamp('read_at')->nullable();
            $table->unique(['note_id', 'event_key', 'user_id']);
            $table->index(['user_id', 'created_at', 'id']);
        });

        Schema::create('note_notice_deliveries', function (Blueprint $table): void {
            $table->id();
            $table->foreignUuid('notice_id')->constrained('note_notices')->cascadeOnDelete();
            $table->foreignUuid('device_id')->constrained('note_notice_devices')->cascadeOnDelete();
            $table->timestamp('available_at');
            $table->uuid('lease')->nullable();
            $table->unsignedSmallInteger('attempts')->default(0);
            $table->string('outcome', 24)->nullable();
            $table->timestamp('finished_at')->nullable();
            $table->unique(['notice_id', 'device_id']);
            $table->index(['finished_at', 'available_at', 'id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('note_notice_deliveries');
        Schema::dropIfExists('note_notices');
        Schema::dropIfExists('note_notice_devices');
    }
};
