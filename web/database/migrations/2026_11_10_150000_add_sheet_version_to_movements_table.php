<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('movements', function (Blueprint $table): void {
            $table->unsignedInteger('sheet_version')->nullable();
        });

        DB::statement('
            WITH ordered AS (
                SELECT id, ROW_NUMBER() OVER (PARTITION BY route_sheet_id ORDER BY occurred_at, id) AS version
                FROM movements
            )
            UPDATE movements
            SET sheet_version = (SELECT version FROM ordered WHERE ordered.id = movements.id)
        ');

        Schema::table('movements', function (Blueprint $table): void {
            $table->unsignedInteger('sheet_version')->nullable(false)->change();
            $table->unique(['route_sheet_id', 'sheet_version']);
        });
    }

    public function down(): void
    {
        Schema::table('movements', function (Blueprint $table): void {
            $table->dropUnique(['route_sheet_id', 'sheet_version']);
            $table->dropColumn('sheet_version');
        });
    }
};
