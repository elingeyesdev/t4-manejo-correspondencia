<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('institutions', function (Blueprint $t) {
            $t->id();
            $t->string('code', 30)->unique();
            $t->string('name', 150);
            $t->timestamps();
        });
        Schema::create('units', function (Blueprint $t) {
            $t->id();
            $t->foreignId('institution_id')->constrained()->restrictOnDelete();
            $t->string('code', 30);
            $t->string('name', 150);
            $t->boolean('enabled')->default(true);
            $t->timestamps();
            $t->unique(['institution_id', 'code']);
            $t->unique(['institution_id', 'name']);
        });
        Schema::table('users', function (Blueprint $t) {
            $t->foreignId('unit_id')->nullable()->constrained()->restrictOnDelete();
            $t->string('role', 30)->default('funcionario');
            $t->boolean('enabled')->default(true);
            $t->unsignedInteger('auth_version')->default(1);
        });
        Schema::create('catalogs', function (Blueprint $t) {
            $t->id();
            $t->string('kind', 20);
            $t->string('code', 30);
            $t->string('name', 150);
            $t->boolean('enabled')->default(true);
            $t->timestamps();
            $t->unique(['kind', 'code']);
            $t->unique(['kind', 'name']);
        });
        Schema::create('documents', function (Blueprint $t) {
            $t->uuid('id')->primary();
            $t->string('code', 60)->unique();
            $t->string('guide', 60)->unique();
            $t->string('sender', 150);
            $t->string('subject', 500);
            $t->date('received_on');
            $t->foreignId('type_id')->constrained('catalogs')->restrictOnDelete();
            $t->foreignId('priority_id')->constrained('catalogs')->restrictOnDelete();
            $t->foreignId('unit_id')->constrained()->restrictOnDelete();
            $t->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $t->uuid('response_to_id')->nullable();
            $t->timestampsTz();

            $t->index(['unit_id', 'created_at']);
        });
        Schema::table('documents', function (Blueprint $t) {
            $t->foreign('response_to_id')->references('id')->on('documents')->restrictOnDelete();
        });
        Schema::create('route_sheets', function (Blueprint $t) {
            $t->uuid('id')->primary();
            $t->string('code', 60)->unique();
            $t->foreignUuid('document_id')->unique()->constrained()->restrictOnDelete();
            $t->string('state', 30)->default('REGISTRADA');
            $t->foreignId('responsible_id')->constrained('users')->restrictOnDelete();
            $t->foreignId('pending_unit_id')->nullable()->constrained('units')->restrictOnDelete();
            $t->unsignedInteger('version')->default(1);
            $t->timestampsTz();
        });
        Schema::create('movements', function (Blueprint $t) {
            $t->uuid('id')->primary();
            $t->foreignUuid('route_sheet_id')->constrained()->restrictOnDelete();
            $t->foreignId('actor_id')->constrained('users')->restrictOnDelete();
            $t->foreignId('origin_unit_id')->nullable()->constrained('units')->restrictOnDelete();
            $t->foreignId('destination_unit_id')->nullable()->constrained('units')->restrictOnDelete();
            $t->string('action', 30);
            $t->string('resulting_state', 30);
            $t->text('reason')->nullable();
            $t->timestampTz('occurred_at');
        });
        Schema::create('requests', function (Blueprint $t) {
            $t->id();
            $t->foreignId('actor_id')->constrained('users')->restrictOnDelete();
            $t->string('operation', 40);
            $t->string('key', 100);
            $t->string('fingerprint', 64);
            $t->foreignUuid('document_id')->constrained()->restrictOnDelete();
            $t->timestampTz('created_at');
            $t->unique(['actor_id', 'operation', 'key']);
        });
        Schema::create('audits', function (Blueprint $t) {
            $t->id();
            $t->foreignId('actor_id')->constrained('users')->restrictOnDelete();
            $t->string('action', 60);
            $t->string('resource', 100);
            $t->timestampTz('occurred_at');
        });
    }

    public function down(): void
    {
        foreach (['audits', 'requests', 'movements', 'route_sheets', 'documents', 'catalogs'] as $table) {
            Schema::dropIfExists($table);
        }
        Schema::table('users', function (Blueprint $t) {
            $t->dropConstrainedForeignId('unit_id');
            $t->dropColumn(['role', 'enabled', 'auth_version']);
        });
        Schema::dropIfExists('units');
        Schema::dropIfExists('institutions');
    }
};
