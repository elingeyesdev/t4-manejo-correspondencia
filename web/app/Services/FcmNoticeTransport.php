<?php

namespace App\Services;

use Google\Auth\ApplicationDefaultCredentials;
use Google\Auth\Credentials\ServiceAccountCredentials;
use Google\Auth\HttpHandler\HttpHandlerFactory;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class FcmNoticeTransport
{
    private ?string $accessToken = null;

    /** @return array{outcome: string, delay?: int} */
    public function send(string $token, string $noticeId): array
    {
        $project = rawurlencode((string) config('fcm.project_id'));
        $response = Http::withToken($this->token())->acceptJson()->connectTimeout(3)->timeout(10)
            ->post("https://fcm.googleapis.com/v1/projects/{$project}/messages:send", [
                'message' => [
                    'token' => $token,
                    'notification' => ['title' => 'Correspondencia', 'body' => 'Tienes una nueva tarea'],
                    'data' => ['notificacion_id' => $noticeId],
                    'android' => ['notification' => ['tag' => $noticeId, 'channel_id' => config('fcm.android_channel')]],
                ],
            ]);

        if ($response->successful()) {
            return ['outcome' => 'accepted'];
        }

        foreach ((array) $response->json('error.details') as $detail) {
            if (is_array($detail) && ($detail['errorCode'] ?? null) === 'UNREGISTERED') {
                return ['outcome' => 'unregistered'];
            }
        }

        if ($response->serverError() || in_array($response->status(), [401, 403, 429], true)) {
            $this->accessToken = null;
            $retry = (string) $response->header('Retry-After');
            $delay = ctype_digit($retry) ? (int) $retry : max(0, (strtotime($retry) ?: 0) - now()->timestamp);

            return ['outcome' => 'retry', 'delay' => min(86400, $delay)];
        }

        return ['outcome' => 'rejected'];
    }

    private function token(): string
    {
        if ($this->accessToken !== null) {
            return $this->accessToken;
        }

        $handler = HttpHandlerFactory::build(new Client(['connect_timeout' => 3, 'timeout' => 10]));
        $scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
        $path = config('fcm.credentials_path');
        $credentials = $path
            ? new ServiceAccountCredentials($scopes, $path)
            : ApplicationDefaultCredentials::getCredentials($scopes, $handler);
        $token = $credentials->fetchAuthToken($handler)['access_token'] ?? null;
        if (! is_string($token) || $token === '') {
            throw new RuntimeException('FCM no devolvió un token de acceso.');
        }

        return $this->accessToken = $token;
    }
}
