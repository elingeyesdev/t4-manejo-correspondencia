<?php

use App\Http\Controllers\AdminController;
use App\Http\Controllers\DocumentController;
use App\Http\Controllers\SessionController;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => redirect()->route('documents.index'));
Route::middleware('guest')->group(function () {
    Route::get('/acceso', [SessionController::class, 'create'])->name('login');
    Route::post('/acceso', [SessionController::class, 'store'])->middleware('throttle:5,1');
});
Route::post('/salir', [SessionController::class, 'destroy'])->middleware('auth')->name('logout');
Route::middleware(['auth', 'operational'])->group(function () {
    Route::get('/documentos', [DocumentController::class, 'index'])->name('documents.index');
    Route::get('/documentos/nuevo', [DocumentController::class, 'create'])->name('documents.create');
    Route::post('/documentos', [DocumentController::class, 'store'])->name('documents.store');
    Route::get('/documentos/{id}', [DocumentController::class, 'show'])->whereUuid('id')->name('documents.show');
    Route::get('/administracion', [AdminController::class, 'index'])->name('admin');
    foreach (['unidades' => 'unit', 'catalogos' => 'catalog', 'usuarios' => 'user'] as $path => $method) {
        Route::post('/administracion/'.$path, [AdminController::class, $method]);
        Route::put('/administracion/'.$path.'/{id}', [AdminController::class, $method]);
    }
});
