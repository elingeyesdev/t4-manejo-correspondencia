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
    })
    ->withExceptions(function (Exceptions $exceptions): void {
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
            if ($status === 409 && $request->routeIs('route-sheets.derive', 'route-sheets.receive')) {
                return redirect()->route('route-sheets.show', $request->route('reference'))
                    ->withErrors(['recorrido' => 'La operación no se guardó. Revisa el estado y vuelve a intentarlo si corresponde.']);
            }

            if (! $request->routeIs('api.route-sheets.*')) {
                return null;
            }

            $code = match ($status) {
                403 => 'ACCION_NO_PERMITIDA',
                404 => 'RECURSO_NO_DISPONIBLE',
                409 => $error->getMessage(),
                default => null,
            };

            $message = match ($code) {
                'ACCION_NO_PERMITIDA' => 'No tienes permiso para esta operación.',
                'RECURSO_NO_DISPONIBLE' => 'La hoja no está disponible.',
                'VERSION_DESACTUALIZADA' => 'La hoja cambió. Actualiza el detalle.',
                'ESTADO_INCOMPATIBLE' => 'El estado de la hoja no permite esta operación.',
                'CLAVE_REUTILIZADA' => 'La clave de solicitud ya se utilizó con otros datos.',
                default => null,
            };

            return $message === null ? null : response()->json([
                'codigo' => $code,
                'message' => $message,
            ], $status);
        });
    })->create();
