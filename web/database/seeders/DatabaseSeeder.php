<?php

namespace Database\Seeders;

use App\Models\Catalog;
use App\Models\Unit;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        if (! DB::table('institutions')->exists()) {
            DB::table('institutions')->insert(['code' => 'DEMO', 'name' => 'Institución de demostración', 'created_at' => now(), 'updated_at' => now()]);
        }
        $institution = DB::table('institutions')->value('id');
        Unit::firstOrCreate(['institution_id' => $institution, 'code' => 'RECEPCION'], ['name' => 'Recepción', 'enabled' => true]);
        foreach ([['tipo', 'OFICIO', 'Oficio'], ['tipo', 'CARTA', 'Carta'], ['prioridad', 'NORMAL', 'Normal'], ['prioridad', 'URGENTE', 'Urgente']] as [$kind,$code,$name]) {
            Catalog::firstOrCreate(compact('kind', 'code'), ['name' => $name, 'enabled' => true]);
        }
    }
}
