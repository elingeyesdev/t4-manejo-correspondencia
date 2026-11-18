<?php

namespace Tests\Feature;

use App\Services\Camunda\StartNotaInterna;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Tests\TestCase;

class StartNotaInternaTest extends TestCase
{
    private const BASE_URL = 'http://camunda.test/v2';

    private const INSTANCE_KEY = '2251799813685320';

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'database.default' => 'sqlite',
            'database.connections.sqlite.database' => ':memory:',
            'database.connections.sqlite.url' => null,
            'camunda.url' => self::BASE_URL,
        ]);
        DB::purge('sqlite');

        foreach ([
            '2026_11_18_000001_create_note_workflow_instances_table.php',
            '2026_11_18_000002_add_retry_at_to_note_workflow_instances_table.php',
        ] as $path) {
            $migration = require database_path('migrations/'.$path);
            $migration->up();
        }

        Http::preventStrayRequests();
        $this->freezeSecond();
    }

    public function test_saturation_allows_a_new_attempt_only_after_the_wait(): void
    {
        Http::fake([
            self::BASE_URL.'/process-instances' => Http::sequence()
                ->push(['title' => 'RESOURCE_EXHAUSTED'], 503)
                ->push(['processInstanceKey' => self::INSTANCE_KEY]),
        ]);
        $service = app(StartNotaInterna::class);
        $noteId = (string) Str::uuid();

        $this->assertNull($service->execute($noteId, ['via-ficticia']));
        $this->travel(1)->second();
        $this->assertNull($service->execute($noteId, ['via-ficticia']));
        Http::assertSentCount(1);

        $this->travel(1)->second();
        $this->assertSame(self::INSTANCE_KEY, $service->execute($noteId, ['via-ficticia']));
        $this->assertSame(self::INSTANCE_KEY, $service->execute($noteId, ['via-ficticia']));
        Http::assertSentCount(2);
        Http::assertSent(fn (Request $request): bool => $request['businessId'] === $noteId
            && $request['variables']['revisores'] === ['via-ficticia']);
        $this->assertDatabaseHas('note_workflow_instances', [
            'note_id' => $noteId,
            'instance_key' => self::INSTANCE_KEY,
            'retry_at' => null,
        ]);
    }

    public function test_an_ambiguous_error_is_reconciled_without_creating_again(): void
    {
        Http::fake([
            self::BASE_URL.'/process-instances' => Http::response(['title' => 'Service unavailable'], 503),
            self::BASE_URL.'/process-instances/search' => Http::sequence()
                ->push(['items' => []])
                ->push(['items' => [['processInstanceKey' => self::INSTANCE_KEY]]]),
        ]);
        $service = app(StartNotaInterna::class);
        $noteId = (string) Str::uuid();

        $this->assertNull($service->execute($noteId, []));
        $this->travel(10)->seconds();
        $this->assertSame(self::INSTANCE_KEY, $service->execute($noteId, []));

        $this->assertCount(1, Http::recorded(fn (Request $request): bool => $request->url() === self::BASE_URL.'/process-instances'));
        $this->assertDatabaseHas('note_workflow_instances', [
            'note_id' => $noteId,
            'instance_key' => self::INSTANCE_KEY,
        ]);
    }
}
