<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('internal_notes', fn (Blueprint $table) => $table->json('document_heading')->nullable());
    }

    public function down(): void
    {
        Schema::table('internal_notes', fn (Blueprint $table) => $table->dropColumn('document_heading'));
    }
};
