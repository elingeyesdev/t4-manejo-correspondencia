<?php

namespace Tests\Feature;

use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PostgresTimestampTest extends TestCase
{
    public function test_a_naive_eloquent_timestamp_keeps_the_same_instant_in_postgresql(): void
    {
        if (DB::getDriverName() !== 'pgsql') {
            $this->markTestSkipped('Requiere PostgreSQL real.');
        }
        $this->assertSame('correspondencia_test', DB::connection()->getDatabaseName());

        // Eloquent serializa timestamps sin offset. Un servidor PostgreSQL con
        // zona local no debe convertir una segunda vez el instante UTC de PHP.
        $instant = CarbonImmutable::parse('2026-11-19T00:15:00-04:00')->utc();
        $stored = DB::selectOne('select cast(? as timestamp with time zone) as instant', [
            $instant->format(DB::connection()->getQueryGrammar()->getDateFormat()),
        ]);

        $this->assertSame($instant->getTimestamp(), CarbonImmutable::parse($stored->instant)->getTimestamp());
        $date = DB::selectOne('select cast(? as date) as day', ['2026-11-18']);
        $this->assertSame('2026-11-18', $date->day);
    }
}
