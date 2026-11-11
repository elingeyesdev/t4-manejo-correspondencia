<?php

use App\Http\Controllers\AdminController;
use App\Http\Controllers\AttachmentController;
use App\Http\Controllers\DocumentController;
use App\Http\Controllers\DocumentHistoryController;
use App\Http\Controllers\RouteSheetController;
use App\Http\Controllers\RouteSheetQrController;
use App\Http\Controllers\SessionController;
use Illuminate\Support\Facades\Route;

Route::post('/sesiones', [SessionController::class, 'token'])->middleware('throttle:5,1');
Route::middleware(['auth:sanctum', 'operational'])->group(function () {
    Route::delete('/sesiones/actual', [SessionController::class, 'revoke']);
    Route::get('/configuracion-registro', [DocumentController::class, 'configuration']);
    Route::get('/documentos', [DocumentController::class, 'index']);
    Route::post('/documentos', [DocumentController::class, 'store']);
    Route::get('/documentos/{id}', [DocumentController::class, 'show'])->whereUuid('id');
    Route::get('/correspondencia/guia/{guide}', [DocumentController::class, 'guide']);
    Route::post('/documentos/{id}/adjuntos', [AttachmentController::class, 'store'])
        ->whereUuid('id');

    Route::get('/documentos/{id}/adjuntos', [AttachmentController::class, 'index'])
        ->whereUuid('id');

    Route::get('/documentos/{id}/adjuntos/{adjunto}/descarga', [AttachmentController::class, 'download'])
        ->whereUuid('id')
        ->whereUuid('adjunto');
    Route::get('/administracion', [AdminController::class, 'index']);
    Route::get('/documentos/{id}/historial', [DocumentHistoryController::class, 'show'])
        ->whereUuid('id');
    Route::get('/hojas/{reference}/destinos', [RouteSheetController::class, 'destinations'])
        ->whereUuid('reference')->name('api.route-sheets.destinations');
    Route::post('/hojas/{reference}/derivaciones', [RouteSheetController::class, 'derive'])
        ->whereUuid('reference')->name('api.route-sheets.derive');
    Route::post('/hojas/{reference}/recepciones', [RouteSheetController::class, 'receive'])
        ->whereUuid('reference')->name('api.route-sheets.receive');
    Route::post('/hojas/{reference}/atenciones', [RouteSheetController::class, 'attend'])
        ->whereUuid('reference')->name('api.route-sheets.attend');
    Route::get('/hojas/{reference}', [RouteSheetQrController::class, 'show'])
        ->whereUuid('reference');
    Route::get('/hojas/{reference}/qr.svg', [RouteSheetQrController::class, 'image'])
        ->whereUuid('reference');
    foreach (['unidades' => 'unit', 'catalogos' => 'catalog', 'usuarios' => 'user'] as $path => $method) {
        Route::post('/'.$path, [AdminController::class, $method]);
        Route::put('/'.$path.'/{id}', [AdminController::class, $method]);
    }
});
