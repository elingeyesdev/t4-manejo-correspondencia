<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('documents', function (Blueprint $table) {
            $table->string('code', 120)->change();
            $table->string('sender', 255)->change();
        });

        Schema::table('route_sheets', function (Blueprint $table) {
            $table->json('camunda_transition')->nullable();
            $table->string('camunda_last_task_key', 32)->nullable();
        });

        Schema::table('internal_notes', function (Blueprint $table) {
            $table->foreignUuid('document_id')->nullable()->unique()->constrained()->restrictOnDelete();
            $table->foreignId('receipt_actor_id')->nullable()->constrained('users')->restrictOnDelete();
            $table->uuid('receipt_key')->nullable();
            $table->unsignedInteger('receipt_version')->nullable();
            $table->string('receipt_task_key', 32)->nullable();
            $table->unique(['receipt_actor_id', 'receipt_key']);
        });
    }

    public function down(): void
    {
        Schema::table('internal_notes', function (Blueprint $table) {
            $table->dropUnique(['document_id']);
            $table->dropUnique(['receipt_actor_id', 'receipt_key']);
            $table->dropConstrainedForeignId('document_id');
            $table->dropConstrainedForeignId('receipt_actor_id');
            $table->dropColumn(['receipt_key', 'receipt_version', 'receipt_task_key']);
        });

        Schema::table('documents', function (Blueprint $table) {
            $table->string('code', 60)->change();
            $table->string('sender', 150)->change();
        });

        Schema::table('route_sheets', function (Blueprint $table) {
            $table->dropColumn(['camunda_transition', 'camunda_last_task_key']);
        });
    }
};
