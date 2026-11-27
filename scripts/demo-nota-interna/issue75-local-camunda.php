<?php

use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\DB;
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
        'http://camunda.local.test/v2/user-tasks/search' => function (Request $request) use ($key) {
            $filter = $request['filter'];
            $sheet = DB::table('note_workflow_instances as workflow')
                ->join('internal_notes as note', 'note.id', '=', 'workflow.note_id')
                ->join('route_sheets as sheet', 'sheet.document_id', '=', 'note.document_id')
                ->where('workflow.instance_key', (string) $filter['processInstanceKey'])
                ->first(['sheet.version', 'sheet.state']);
            if ($sheet?->state === 'CERRADA') {
                return Http::response(['items' => []]);
            }

            // Cada vuelta de AtenderNota representa una tarea diferente.
            $filter['sheetVersion'] = $sheet?->version;

            return Http::response(['items' => [['userTaskKey' => $key(json_encode($filter, JSON_THROW_ON_ERROR))]]]);
        },
        'http://camunda.local.test/v2/user-tasks/*' => fn (Request $request) => $request->method() === 'POST'
            ? Http::response(null, 204)
            : Http::response(['state' => 'CREATED']),
    ]);
}
