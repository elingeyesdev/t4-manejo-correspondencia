<?php

use App\Http\Middleware\EnsureOperational;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(web: __DIR__.'/../routes/web.php', api: __DIR__.'/../routes/api.php', commands: __DIR__.'/../routes/console.php', health: '/up')
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias(['operational' => EnsureOperational::class]);
        $middleware->trimStrings(except: ['motivo', 'observacion']);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->dontFlash(['firma']);

        $exceptions->render(function (AuthenticationException $error, Request $request) {
            if ($request->routeIs('api.route-sheets.*')) {
                return response()->json([
                    'codigo' => 'SESION_REQUERIDA',
                    'message' => 'Inicia sesión para continuar.',
                ], 401);
            }
        });

        $exceptions->render(function (ValidationException $error, Request $request) {
            if ($request->routeIs('api.route-sheets.*')) {
                return response()->json([
                    'codigo' => 'VALIDACION_FALLIDA',
                    'message' => 'Revisa los campos indicados.',
                    'errors' => $error->errors(),
                ], 422);
            }
        });

        $exceptions->render(function (HttpExceptionInterface $error, Request $request) {
            $status = $error->getStatusCode();
            if ($status === 409 && $request->routeIs('documents.responses.store')) {
                return redirect()->route('documents.show', $request->route('id'))
                    ->withErrors(['recorrido' => 'La respuesta no se guardó. Revisa el estado del expediente.'])
                    ->withInput($request->only('_form', 'remitente', 'asunto', 'fecha', 'tipo_id', 'prioridad_id'));
            }

            if ($status === 503 && $request->routeIs('route-sheets.derive', 'route-sheets.receive', 'route-sheets.attend', 'route-sheets.close')) {
                return redirect()->route('route-sheets.show', $request->route('reference'))
                    ->withErrors(['recorrido' => 'La acción está pendiente de confirmación. Reintenta desde el detalle.'])
                    ->withInput($request->only('_form', 'version', 'request_key', 'destino_unidad_id', 'observacion', 'motivo', 'confirmar'));
            }

            if ($status === 409 && $request->routeIs('route-sheets.derive', 'route-sheets.receive', 'route-sheets.attend', 'route-sheets.close')) {
                return redirect()->route('route-sheets.show', $request->route('reference'))
                    ->withErrors(['recorrido' => 'La operación no se guardó. Revisa el estado y vuelve a intentarlo si corresponde.'])
                    ->withInput($request->only('_form', 'observacion', 'motivo'));
            }

            if (! $request->routeIs('api.route-sheets.*')) {
                return null;
            }

            $code = match ($status) {
                403 => 'ACCION_NO_PERMITIDA',
                404 => 'RECURSO_NO_DISPONIBLE',
                409 => $error->getMessage(),
                503 => 'CAMUNDA_NO_DISPONIBLE',
                default => null,
            };

            $message = match ($code) {
                'ACCION_NO_PERMITIDA' => 'No tienes permiso para esta operación.',
                'RECURSO_NO_DISPONIBLE' => 'La hoja no está disponible.',
                'VERSION_DESACTUALIZADA' => 'La hoja cambió. Actualiza el detalle.',
                'ESTADO_INCOMPATIBLE' => 'El estado de la hoja no permite esta operación.',
                'CLAVE_REUTILIZADA' => 'La clave de solicitud ya se utilizó con otros datos.',
                'ACCION_PENDIENTE' => 'Hay una acción pendiente. Reintenta la solicitud original.',
                'CAMUNDA_NO_DISPONIBLE' => 'La acción no fue confirmada. Reintenta con la misma solicitud.',
                default => null,
            };

            return $message === null ? null : response()->json([
                'codigo' => $code,
                'message' => $message,
            ], $status);
        });
    })->create();
