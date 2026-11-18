<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('note_workflow_instances', function (Blueprint $table): void {
            $table->uuid('note_id')->primary();
            $table->string('instance_key', 32)->nullable()->unique();
            $table->string('reviewers_fingerprint', 64);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('note_workflow_instances');
    }
};
