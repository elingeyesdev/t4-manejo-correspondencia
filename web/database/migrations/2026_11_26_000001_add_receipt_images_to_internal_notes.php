<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('internal_notes', fn (Blueprint $table) => $table->text('receipt_images')->nullable());
    }

    public function down(): void
    {
        Schema::table('internal_notes', fn (Blueprint $table) => $table->dropColumn('receipt_images'));
    }
};
