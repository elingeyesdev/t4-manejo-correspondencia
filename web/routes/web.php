<?php

use App\Http\Controllers\AdminController;
use App\Http\Controllers\AttachmentWebController;
use App\Http\Controllers\DocumentController;
use App\Http\Controllers\InternalNoteController;
use App\Http\Controllers\NoteNoticeController;
use App\Http\Controllers\RouteSheetController;
use App\Http\Controllers\RouteSheetQrController;
use App\Http\Controllers\SessionController;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => redirect()->route('documents.index'));
Route::middleware('guest')->group(function () {
    Route::get('/acceso', [SessionController::class, 'create'])->name('login');
    Route::post('/acceso', [SessionController::class, 'store'])->middleware('throttle:5,1');
});
Route::post('/salir', [SessionController::class, 'destroy'])->middleware('auth')->name('logout');
Route::middleware(['auth', 'operational'])->group(function () {
    Route::get('/notificaciones', [NoteNoticeController::class, 'index'])->name('notices.index');
    Route::put('/notificaciones/{id}/lectura', [NoteNoticeController::class, 'read'])->whereUuid('id')->name('notices.read');
    Route::prefix('notas-internas')->name('notes.')->controller(InternalNoteController::class)->group(function () {
        Route::get('/', 'index')->name('index');
        Route::get('/nueva', 'create')->name('create');
        Route::post('/vista-previa', 'draftDocument')->middleware('throttle:40,1')->name('preview-draft');
        Route::post('/', 'store')->name('store');
        Route::get('/{id}', 'show')->whereUuid('id')->name('show');
        Route::get('/{id}/seguimiento', 'tracking')->whereUuid('id')->name('tracking');
        Route::get('/{id}/documento', 'document')->whereUuid('id')->name('document');
        Route::get('/{id}/documento.pdf', 'download')->whereUuid('id')->name('download');
        Route::post('/{id}/vista-previa', 'actionDocument')->whereUuid('id')->middleware('throttle:20,1')->name('preview-action');
        Route::get('/{id}/editar', 'edit')->whereUuid('id')->name('edit');
        Route::patch('/{id}', 'update')->whereUuid('id')->name('update');
        Route::post('/{id}/solicitud-firma', 'requestSignature')->whereUuid('id')->name('request-signature');
        Route::post('/{id}/firmas', 'sign')->whereUuid('id')->name('sign');
        Route::post('/{id}/emision', 'emit')->whereUuid('id')->name('emit');
        Route::post('/{id}/conformidades', 'approve')->whereUuid('id')->name('approve');
        Route::post('/{id}/recepciones', 'receive')->whereUuid('id')->name('receive');
    });
    Route::get('/documentos', [DocumentController::class, 'index'])->name('documents.index');
    Route::get('/documentos/nuevo', [DocumentController::class, 'create'])->name('documents.create');
    Route::post('/documentos', [DocumentController::class, 'store'])->name('documents.store');
    Route::get('/documentos/{id}', [DocumentController::class, 'show'])->whereUuid('id')->name('documents.show');
    Route::post('/documentos/{id}/respuestas', [RouteSheetController::class, 'storeResponse'])
        ->whereUuid('id')->name('documents.responses.store');
    Route::post('/documentos/{id}/adjuntos', [AttachmentWebController::class, 'store'])->whereUuid('id')->name('attachments.store');
    Route::get('/documentos/{id}/adjuntos/{adjunto}/ver', [AttachmentWebController::class, 'view'])->whereUuid('id')->whereUuid('adjunto')->name('attachments.view');
    Route::get('/documentos/{id}/adjuntos/{adjunto}/descarga', [AttachmentWebController::class, 'download'])->whereUuid('id')->whereUuid('adjunto')->name('attachments.download');
    Route::get('/administracion', [AdminController::class, 'index'])->name('admin');
    Route::post('/hojas/{reference}/derivaciones', [RouteSheetController::class, 'derive'])
        ->whereUuid('reference')->name('route-sheets.derive');
    Route::post('/hojas/{reference}/recepciones', [RouteSheetController::class, 'receive'])
        ->whereUuid('reference')->name('route-sheets.receive');
    Route::post('/hojas/{reference}/atenciones', [RouteSheetController::class, 'attend'])
        ->whereUuid('reference')->name('route-sheets.attend');
    Route::post('/hojas/{reference}/cierre', [RouteSheetController::class, 'close'])
        ->whereUuid('reference')->name('route-sheets.close');
    Route::get('/hojas/{reference}', [RouteSheetQrController::class, 'show'])
        ->whereUuid('reference')
        ->name('route-sheets.show');
    Route::get('/hojas/{reference}/qr.svg', [RouteSheetQrController::class, 'image'])
        ->whereUuid('reference')
        ->name('route-sheets.qr');
    foreach (['unidades' => 'unit', 'catalogos' => 'catalog', 'usuarios' => 'user'] as $path => $method) {
        Route::post('/administracion/'.$path, [AdminController::class, $method]);
        Route::put('/administracion/'.$path.'/{id}', [AdminController::class, $method]);
    }
});
