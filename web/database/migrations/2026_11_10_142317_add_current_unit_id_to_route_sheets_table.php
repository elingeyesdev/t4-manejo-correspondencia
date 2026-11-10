<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('route_sheets', function (Blueprint $table): void {
            $table->foreignId('current_unit_id')
                ->nullable()
                ->constrained('units')
                ->restrictOnDelete();
        });

        DB::table('route_sheets')->whereNull('current_unit_id')->update([
            'current_unit_id' => DB::raw(
                '(SELECT documents.unit_id FROM documents WHERE documents.id = route_sheets.document_id)'
            ),
        ]);

        Schema::table('route_sheets', function (Blueprint $table): void {
            $table->unsignedBigInteger('current_unit_id')->nullable(false)->change();
        });
    }

    public function down(): void
    {
        Schema::table('route_sheets', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('current_unit_id');
        });
    }
};
