<?php

use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;

// Motor simulado para el lanzador Windows con una base SQLite aislada.
function issue75SimulateCamunda(): void
{
    $key = fn (string $value) => (string) (1 + hexdec(substr(hash('sha256', $value), 0, 12)));
    Http::preventStrayRequests();
    Http::fake([
        'http://camunda.local.test/v2/process-instances' => fn (Request $request) => Http::response([
            'processInstanceKey' => $key((string) $request['businessId']),
        ]),
        'http://camunda.local.test/v2/process-instances/search' => fn (Request $request) => Http::response([
            'items' => [['processInstanceKey' => $key((string) ($request['filter']['businessId'] ?? ''))]],
        ]),
        'http://camunda.local.test/v2/user-tasks/search' => fn (Request $request) => Http::response([
            'items' => [['userTaskKey' => $key(json_encode($request['filter'], JSON_THROW_ON_ERROR))]],
        ]),
        'http://camunda.local.test/v2/user-tasks/*' => fn (Request $request) => $request->method() === 'POST'
            ? Http::response(null, 204)
            : Http::response(['state' => 'CREATED']),
    ]);
}
