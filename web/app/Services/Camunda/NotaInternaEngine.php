<?php

namespace App\Services\Camunda;

use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;
use LogicException;
use UnexpectedValueException;

class NotaInternaEngine
{
    private const PROCESS_ID = 'nota_interna';

    /** @param list<string> $reviewers Identificadores de los revisores en orden de VÍA. */
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
            throw new UnexpectedValueException('Camunda no devolvió una búsqueda inequívoca de la nota.');
        }

        return $items === [] ? null : $this->instanceKey($items[0]['processInstanceKey'] ?? null);
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
            throw new UnexpectedValueException('Camunda devolvió una clave de instancia inválida.');
        }

        return $key;
    }
}
