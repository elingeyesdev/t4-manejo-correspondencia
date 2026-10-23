<?php

use App\Http\Controllers\AdminController;
use App\Http\Controllers\DocumentController;
use App\Http\Controllers\SessionController;
use Illuminate\Support\Facades\Route;

Route::post('/sesiones', [SessionController::class, 'token'])->middleware('throttle:5,1');
Route::middleware(['auth:sanctum', 'operational'])->group(function () {
    Route::delete('/sesiones/actual', [SessionController::class, 'revoke']);
    Route::get('/documentos', [DocumentController::class, 'index']);
    Route::post('/documentos', [DocumentController::class, 'store']);
    Route::get('/documentos/{id}', [DocumentController::class, 'show'])->whereUuid('id');
    Route::get('/correspondencia/guia/{guide}', [DocumentController::class, 'guide']);
    Route::get('/administracion', [AdminController::class, 'index']);
    foreach (['unidades' => 'unit', 'catalogos' => 'catalog', 'usuarios' => 'user'] as $path => $method) {
        Route::post('/'.$path, [AdminController::class, $method]);
        Route::put('/'.$path.'/{id}', [AdminController::class, $method]);
    }
});
