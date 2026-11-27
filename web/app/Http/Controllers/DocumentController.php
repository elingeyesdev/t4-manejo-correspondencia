<?php

namespace App\Http\Controllers;

use App\Http\Requests\StoreDocumentRequest;
use App\Models\Attachment;
use App\Models\Catalog;
use App\Models\Document;
use App\Models\InternalNote;
use App\Models\Unit;
use App\Services\DocumentHistory;
use App\Services\RegisterDocument;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class DocumentController extends Controller
{
    public function index(Request $r)
    {
        $docs = Document::visibleTo($r->user())
            ->whereNull('response_to_id')
            ->with(['sheet', 'unit'])
            ->latest()
            ->orderBy('id')
            ->paginate(15);
        if ($r->is('api/*')) {
            return response()->json($docs->through(fn ($d) => $d->payload()));
        }

        $docs->getCollection()->load([
            'internalNote' => fn ($notes) => $notes->visibleTo($r->user())->select('id', 'document_id', 'body'),
            'previewAttachments' => fn ($attachments) => $attachments->select('id', 'document_id', 'mime_type', 'original_name'),
        ]);

        $sent = InternalNote::visibleTo($r->user())
            ->whereIn('state', [InternalNote::REVIEW, InternalNote::RECEIVE])
            ->whereNull('document_id')
            ->with('recipient')
            ->latest('updated_at')
            ->paginate(10, pageName: 'remitidas')->withQueryString();

        return view('documents.index', ['documents' => $docs, 'sentNotes' => $sent]);
    }

    public function configuration(Request $r)
    {
        abort_unless($r->user()->canRegister(), 403);

        return response()->json([
            'unidades' => Unit::where('enabled', true)->when(! $r->user()->isAdmin(), fn ($q) => $q->whereKey($r->user()->unit_id))->get(['id', 'name']),
            'tipos' => Catalog::where(['kind' => 'tipo', 'enabled' => true])->get(['id', 'name']),
            'prioridades' => Catalog::where(['kind' => 'prioridad', 'enabled' => true])->get(['id', 'name']),
        ]);
    }

    public function create(Request $r)
    {
        abort_unless($r->user()->canRegister(), 403);

        return view('documents.create', ['units' => Unit::where('enabled', true)->when(! $r->user()->isAdmin(), fn ($q) => $q->whereKey($r->user()->unit_id))->get(),
            'types' => Catalog::where(['kind' => 'tipo', 'enabled' => true])->get(), 'priorities' => Catalog::where(['kind' => 'prioridad', 'enabled' => true])->get(),
            'requestKey' => (string) Str::uuid()]);
    }

    public function store(StoreDocumentRequest $r, RegisterDocument $service)
    {
        [$doc,$created] = $service->execute($r->user(), $r->validated());

        return $r->is('api/*') ? response()->json($doc->payload(), $created ? 201 : 200)
            : redirect()->route('documents.show', $doc->id)->with('status', $created ? 'Correspondencia registrada.' : 'Solicitud ya registrada; se recuperó el mismo documento.');
    }

    public function show(Request $r, string $id, DocumentHistory $historyService)
    {
        $doc = Document::visibleTo($r->user())->findOrFail($id);

        $payload = $doc->detailPayload($r->user());

        if ($r->is('api/*')) {
            return response()->json($payload);
        }

        $doc->load(['internalNote' => fn ($notes) => $notes->visibleTo($r->user()), 'previewAttachments']);

        return view('documents.show', [
            'document' => $doc,
            'receiptStamp' => $doc->internalNote?->receiptStamp(),
            'payload' => $payload,
            'destinations' => in_array('derivar', $payload['acciones_permitidas'], true)
                ? $doc->sheet->eligibleDestinations()->orderBy('name')->get(['id', 'name'])
                : collect(),
            'responseCatalogs' => in_array('responder', $payload['acciones_permitidas'], true)
                ? Catalog::where('enabled', true)->whereIn('kind', ['tipo', 'prioridad'])
                    ->orderBy('name')->get(['id', 'kind', 'name'])->groupBy('kind')
                : collect(),
            'history' => $historyService->execute($r->user(), $id),
            'attachments' => Attachment::where('document_id', $doc->id)
                ->latest()
                ->orderBy('id')
                ->paginate(15, ['*'], 'adjuntos_page'),
        ]);
    }

    public function guide(Request $r, string $guide)
    {
        $doc = Document::visibleTo($r->user())->where('guide', strtoupper(trim($guide)))->first();
        if (! $doc) {
            return response()->json(['codigo' => 'GUIA_NO_ENCONTRADA', 'message' => 'No se encontró una guía accesible.'], 404);
        }

        return response()->json($doc->detailPayload($r->user()));
    }
}
