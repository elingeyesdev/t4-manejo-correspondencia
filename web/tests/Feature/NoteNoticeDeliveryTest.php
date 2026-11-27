<?php

namespace Tests\Feature;

use App\Services\FcmNoticeTransport;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use ReflectionProperty;
use Tests\TestCase;

class NoteNoticeDeliveryTest extends TestCase
{
    public function test_pending_push_delivery_runs_each_second_without_overlapping(): void
    {
        $events = array_values(array_filter(app(Schedule::class)->events(),
            fn ($event) => str_contains($event->command ?? '', 'correspondencia:enviar-avisos')));

        $this->assertCount(1, $events);
        $event = $events[0];
        $this->assertSame(1, $event->repeatSeconds);
        $this->assertTrue($event->withoutOverlapping);

        config(['fcm.project_id' => null]);
        $this->assertFalse($event->filtersPass($this->app));
        config(['fcm.project_id' => 'proyecto-ficticio']);
        $this->assertTrue($event->filtersPass($this->app));
    }

    public function test_visible_android_notice_is_sent_with_high_priority_and_private_payload(): void
    {
        config(['fcm.project_id' => 'proyecto-ficticio', 'fcm.android_channel' => 'correspondencia']);
        Http::preventStrayRequests();
        Http::fake(['fcm.googleapis.com/v1/projects/proyecto-ficticio/messages:send' => Http::response(['name' => 'projects/proyecto-ficticio/messages/1'])]);

        $transport = new FcmNoticeTransport;
        (new ReflectionProperty($transport, 'accessToken'))->setValue($transport, 'acceso-ficticio');
        $this->assertSame(['outcome' => 'accepted'], $transport->send('dispositivo-ficticio', 'aviso-ficticio'));

        Http::assertSent(fn (Request $request) => $request['message'] === [
            'token' => 'dispositivo-ficticio',
            'notification' => ['title' => 'Correspondencia', 'body' => 'Tienes una nueva tarea'],
            'data' => ['notificacion_id' => 'aviso-ficticio'],
            'android' => [
                'priority' => 'high',
                'notification' => ['tag' => 'aviso-ficticio', 'channel_id' => 'correspondencia'],
            ],
        ]);
        Http::assertSentCount(1);
    }
}
