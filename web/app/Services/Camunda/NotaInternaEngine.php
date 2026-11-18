<?php

namespace App\Services\Camunda;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;
use LogicException;
use UnexpectedValueException;

class NotaInternaEngine
{
    private const PROCESS_ID = 'nota_interna';

    /** @param list<string> $reviewers Identificadores de los revisores en orden de V├ìA. */
    public function start(string $noteId, array $reviewers): string
    {
        $response = $this->client()->post('process-instances', [
            'processDefinitionId' => self::PROCESS_ID,
            'businessId' => $noteId,
            'variables' => ['revisores' => $reviewers],
        ])->throw();

        return $this->instanceKey($response->json('processInstanceKey'));
    }

    public function findInstance(string $noteId): ?string
    {
        $items = $this->client()->post('process-instances/search', [
            'filter' => ['processDefinitionId' => self::PROCESS_ID, 'businessId' => $noteId],
            'page' => ['limit' => 2],
        ])->throw()->json('items');

        if (! is_array($items) || count($items) > 1) {
            throw new UnexpectedValueException('Camunda no devolvi├│ una b├║squeda inequ├¡voca de la nota.');
        }

        return $items === [] ? null : $this->instanceKey($items[0]['processInstanceKey'] ?? null);
    }

    public function activeReviewTask(string $instance, string $reviewer): ?string
    {
        $items = $this->client()->post('user-tasks/search', [
            'filter' => [
                'processInstanceKey' => $instance,
                'elementId' => 'RevisarVia',
                'state' => 'CREATED',
                'assignee' => $reviewer,
            ],
            'page' => ['limit' => 2],
        ])->throw()->json('items');

        if (! is_array($items) || count($items) > 1) {
            throw new UnexpectedValueException('Camunda no devolvi├│ una tarea de revisi├│n inequ├¡voca.');
        }

        return $items === [] ? null : $this->instanceKey($items[0]['userTaskKey'] ?? null);
    }

    public function completeReviewTask(string $key): bool
    {
        $task = $this->client()->get("user-tasks/{$key}");
        if (! $task->notFound() && $task->throw()->json('state') === 'COMPLETED') {
            return true;
        }

        try {
            $response = $this->client()->post("user-tasks/{$key}/completion", ['variables' => (object) []]);
        } catch (ConnectionException) {
            return false;
        }

        if (in_array($response->status(), [404, 409, 503, 504], true)) {
            return false;
        }

        return $response->throw()->noContent();
    }

    private function client(): PendingRequest
    {
        $url = config('camunda.url');

        if (! is_string($url) || trim($url) === '') {
            throw new LogicException('Configura CAMUNDA_URL antes de iniciar una Nota Interna.');
        }

        return Http::baseUrl(rtrim($url, '/'))->acceptJson()->connectTimeout(3)->timeout(10);
    }

    private function instanceKey(mixed $key): string
    {
        if (! is_string($key) || ! ctype_digit($key)) {
            throw new UnexpectedValueException('Camunda devolvi├│ una clave de instancia inv├ílida.');
        }

        return $key;
    }
}
