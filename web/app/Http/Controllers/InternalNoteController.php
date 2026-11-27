<?php

namespace App\Http\Controllers;

use App\Http\Requests\InternalNoteDraftRequest;
use App\Models\Document;
use App\Models\InternalNote;
use App\Models\InternalNoteSignature;
use App\Models\Unit;
use App\Models\User;
use App\Services\InternalNoteWorkflow;
use App\Services\InstitutionalNoteDocument;
use App\Services\ReceiveInternalNote;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class InternalNoteController extends Controller
{
    public function index(Request $request)
    {
        $actor = $request->user();
        $api = $request->is('api/*');
        $filters = $request->validate([
            'bandeja' => ['sometimes', Rule::in(['mis_notas', 'por_firmar', 'por_revisar', 'por_recibir', 'por_atender', 'copias'])],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:50'],
        ]);
        $tray = $filters['bandeja'] ?? ($api ? 'por_revisar' : 'mis_notas');
        $query = $this->visibleNotes($actor);

        match ($tray) {
            'mis_notas' => $query->where('author_id', $actor->id),
            'por_firmar' => $query->where('author_id', $actor->id)->where('origin_unit_id', $actor->unit_id)
                ->where('state', InternalNote::DRAFT)->whereNotNull('signature_requested_at'),
            'por_revisar' => $query->where('state', InternalNote::REVIEW)
                ->whereHas('participants', fn ($via) => $via->where('role', 'via')->where('user_id', $actor->id)
                    ->whereColumn('position', 'internal_notes.active_position')),
            'por_recibir' => $query->where(fn (Builder $pending) => $pending
                ->where(fn (Builder $initial) => $initial->where('state', InternalNote::RECEIVE)
                    ->where('recipient_unit_id', $actor->unit_id)
                    ->where(fn (Builder $assigned) => $assigned->whereNull('receipt_actor_id')->orWhere('receipt_actor_id', $actor->id)))
                ->orWhereHas('document.sheet', fn (Builder $sheet) => $sheet->where('state', 'PENDIENTE_RECEPCION')
                    ->where('pending_unit_id', $actor->unit_id)))
                ->whereRaw($actor->role === 'funcionario' ? '1 = 1' : '1 = 0'),
            'copias' => $query->whereIn('state', [InternalNote::RECEIVE, InternalNote::RECEIVED])
                ->whereHas('participants', fn ($cc) => $cc->where('role', 'cc')->where('user_id', $actor->id)),
            'por_atender' => $query->whereHas('document.sheet', fn (Builder $sheet) => $sheet
                ->whereIn('state', ['RECIBIDA', 'EN_ATENCION'])->where('responsible_id', $actor->id)
                ->where('current_unit_id', $actor->unit_id)),
        };

        $notes = $query->orderByDesc('updated_at')->orderByDesc('id')->paginate($filters['per_page'] ?? 15)->withQueryString();
        if ($api) {
            return response()->json([
                'data' => $notes->map(fn (InternalNote $note) => $this->payload($note, $actor))->all(),
                'meta' => [
                    'current_page' => $notes->currentPage(),
                    'per_page' => $notes->perPage(),
                    'total' => $notes->total(),
                    'last_page' => $notes->lastPage(),
                ],
            ]);
        }

        return view('internal-notes.index', compact('notes', 'tray'));
    }

    public function create(Request $request)
    {
        return $this->form($request->user(), new InternalNote);
    }

    public function edit(Request $request, string $id)
    {
        $note = $this->find($request->user(), $id);
        abort_unless($this->canEdit($note, $request->user()), 403);

        return $this->form($request->user(), $note);
    }

    public function tracking(Request $request, string $id)
    {
        $note = $this->find($request->user(), $id);
        $summary = $this->routeSummary($note);

        return response()->json($summary + ['seguimiento' => $this->progress($note, $summary), 'version_documento' => $note->version])
            ->header('Cache-Control', 'private, no-store');
    }

    public function show(Request $request, string $id)
    {
        $actor = $request->user();
        $note = $this->find($actor, $id)->load('participants.user.unit', 'author');
        $via = $note->participants->first(fn ($via) => $via->role === 'via' && $via->user_id === $actor->id
            && $via->position === $note->active_position);
        $data = $this->payload($note, $actor, true);
        if ($request->is('api/*')) {
            return response()->json($data);
        }

        $actionKey = (string) Str::uuid();

        $canOpenSheet = $note->document_id !== null && Document::visibleTo($actor)->whereKey($note->document_id)->exists();
        $retryVia = $via?->action_key !== null && $note->signatures()->where('action', InternalNoteSignature::VIA)
            ->where('user_id', $actor->id)->where('request_key', $via->action_key)->exists();
        $note->load('document.sheet.movements.actor', 'document.sheet.movements.destinationUnit');

        $senderSignature = $note->senderSignatures()
            ->where('user_id', $note->author_id)
            ->where('note_version', $note->emission_version ?? $note->version)
            ->first(['signed_at']);

        return view('internal-notes.show', compact('note', 'via', 'data', 'actionKey', 'canOpenSheet', 'retryVia', 'senderSignature'));
    }

    public function store(InternalNoteDraftRequest $request, InternalNoteWorkflow $workflow)
    {
        $note = $workflow->save($request->user(), $request->validated());

        return $this->result($request, $note, 'Borrador guardado.', 201);
    }

    public function document(Request $request, string $id, InstitutionalNoteDocument $document)
    {
        return $this->htmlDocument($document->html($this->find($request->user(), $id)));
    }

    private function htmlDocument(string $html)
    {
        return response($html)
            ->header('Cache-Control', 'private, no-store');
    }

    public function download(Request $request, string $id, InstitutionalNoteDocument $document)
    {
        $note = $this->find($request->user(), $id);
        $version = $request->validate(['version' => ['sometimes', 'integer', 'min:1']])['version'] ?? null;
        abort_if($version !== null && (int) $version !== $note->version, 409, 'La nota cambió. Vuelve a abrir la vista previa.');
        $filename = Str::slug($note->cite ?? 'borrador-nota-interna').'.pdf';

        return $this->pdfResponse($document->pdf($note), $filename, $note->version,
            ! $request->is('api/*') && $request->boolean('descargar'));
    }

    public function draftDocument(Request $request, InstitutionalNoteDocument $document)
    {
        $actor = $request->user();
        $input = $request->validate([
            'asunto' => ['nullable', 'string', 'max:200'],
            'referencia' => ['nullable', 'string', 'max:200'],
            'cuerpo' => ['nullable', 'string', 'max:20000'],
            'destinatario_unidad_id' => ['nullable', 'integer'],
            'vias_usuario_ids' => ['nullable', 'array', 'max:10'],
            'vias_usuario_ids.*' => ['nullable', 'integer'],
            'cc_usuario_ids' => ['nullable', 'array', 'max:50'],
            'cc_usuario_ids.*' => ['integer'],
            'borrador' => ['nullable', 'uuid'],
        ]);
        $saved = isset($input['borrador']) ? $this->find($actor, $input['borrador']) : null;
        abort_if($saved !== null && ! $this->canEdit($saved, $actor), 403);
        $units = Unit::where('institution_id', $actor->unit->institution_id)->where('enabled', true);
        $recipient = isset($input['destinatario_unidad_id'])
            ? (clone $units)->whereKey($input['destinatario_unidad_id'])->value('name') : null;
        $byRole = ['via' => $input['vias_usuario_ids'] ?? [], 'cc' => $input['cc_usuario_ids'] ?? []];
        $accounts = User::with('unit')->where('enabled', true)->whereIn('unit_id', $units->select('id'))
            ->whereIn('id', array_merge(...array_values($byRole)))->get()->keyBy('id');
        $people = [];
        foreach ($byRole as $role => $ids) {
            foreach (array_unique($ids) as $id) {
                if ($person = $accounts->get($id)) {
                    $people[] = ['id' => $person->id, 'role' => $role, 'name' => $person->name, 'unit' => $person->unit->name];
                }
            }
        }
        $draft = new InternalNote([
            'subject' => $input['asunto'] ?? '',
            'reference' => $input['referencia'] ?? null,
            'body' => $input['cuerpo'] ?? '',
            'created_at' => $saved?->created_at ?? now(),
            'document_heading' => [
                'sender' => ['name' => $actor->name, 'unit' => $actor->unit->name],
                'recipient' => $recipient,
                'people' => $people,
            ],
        ]);

        return $document->configured() ? $this->pdfResponse($document->pdf($draft), 'borrador-nota-interna.pdf')
            : $this->htmlDocument($document->html($draft));
    }

    public function actionDocument(Request $request, string $id, InstitutionalNoteDocument $document)
    {
        $actor = $request->user();
        $note = $this->find($actor, $id);
        $input = $request->validate([
            'version' => ['required', 'integer', 'min:1'],
            'accion' => ['required', Rule::in(['firmar_borrador', 'dar_conformidad', 'confirmar_primera_recepcion'])],
        ]);
        abort_unless(in_array($input['accion'], $this->payload($note, $actor)['acciones_permitidas'], true), 403);
        abort_unless((int) $input['version'] === $note->version, 409);

        $preview = [
            'action' => $input['accion'],
            'name' => $actor->name,
            'unit' => $actor->unit->name,
            'images' => $this->images($request),
            'strokes' => $this->signatureStrokes($request) ?? [],
        ];

        return $request->is('api/*') || $document->configured()
            ? $this->pdfResponse($document->pdf($note, $preview), 'vista-previa-no-confirmada.pdf', $note->version)
            : $this->htmlDocument($document->html($note, $preview));
    }

    private function pdfResponse(string $pdf, string $filename, ?int $version = null, bool $download = false)
    {
        return response($pdf, 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => ($download ? 'attachment' : 'inline').'; filename="'.$filename.'"',
            'Cache-Control' => 'private, no-store',
            ...($version === null ? [] : ['X-Note-Version' => (string) $version]),
        ]);
    }

    public function update(InternalNoteDraftRequest $request, string $id, InternalNoteWorkflow $workflow)
    {
        $note = $workflow->save($request->user(), $request->validated(), $this->find($request->user(), $id));

        return $this->result($request, $note, 'Borrador actualizado.');
    }

    public function emit(Request $request, string $id, InternalNoteWorkflow $workflow)
    {
        $data = $this->action($request);
        $note = $workflow->emit($request->user(), $this->find($request->user(), $id), (int) $data['version'], $data['request_key']);
        $pending = $note->state === InternalNote::EMITTING;

        return $this->result($request, $note, $pending ? 'Emisión pendiente. Puedes reintentar desde esta nota.' : 'Nota emitida.', $pending ? 202 : 200);
    }

    public function requestSignature(Request $request, string $id, InternalNoteWorkflow $workflow)
    {
        $data = $request->validate(['version' => ['required', 'integer', 'min:1']]);
        $note = $workflow->requestSignature($request->user(), $this->find($request->user(), $id), (int) $data['version']);

        return $this->result($request, $note, 'Borrador enviado a firma.');
    }

    public function sign(Request $request, string $id, InternalNoteWorkflow $workflow)
    {
        $data = $this->action($request);
        $note = $workflow->sign($request->user(), $this->find($request->user(), $id), (int) $data['version'],
            $data['request_key'], $this->signature($request));

        return $this->result($request, $note, 'Firma registrada.');
    }

    public function approve(Request $request, string $id, InternalNoteWorkflow $workflow)
    {
        $data = $this->action($request);
        $note = $workflow->approve($request->user(), $this->find($request->user(), $id), (int) $data['version'],
            $data['request_key'], $this->signature($request));
        $pending = $note->participants()->where('role', 'via')->where('user_id', $request->user()->id)->whereNull('confirmed_at')->exists();

        return $this->result($request, $note, $pending ? 'Conformidad pendiente. Puedes reintentar desde esta nota.' : 'Conformidad registrada.', $pending ? 202 : 200);
    }

    public function receive(Request $request, string $id, ReceiveInternalNote $receipt)
    {
        $actor = $request->user();
        $data = $this->action($request);
        $note = $receipt->execute($actor, $this->find($actor, $id), (int) $data['version'], $data['request_key'], $this->images($request));
        $pending = $note->document_id === null;

        return $this->result($request, $note, $pending ? 'Recepción pendiente. Puedes reintentar desde esta nota.' : 'Recepción confirmada.', $pending ? 202 : 200);
    }

    private function action(Request $request): array
    {
        if ($request->is('api/*')) {
            $request->merge(['request_key' => $request->header('Idempotency-Key')]);
        }

        return $request->validate(['version' => ['required', 'integer', 'min:1'], 'request_key' => ['required', 'uuid']]);
    }

    private function signature(Request $request): ?array
    {
        $images = $this->images($request);
        $strokes = $this->signatureStrokes($request);

        if ($images === []) {
            return $strokes;
        }

        return ['strokes' => $strokes ?? [], 'images' => $images];
    }

    private function images(Request $request): array
    {
        $files = $request->validate([
            'imagen_firma' => ['nullable', 'file', 'mimetypes:image/png,image/jpeg', 'max:512', 'dimensions:max_width=2000,max_height=2000'],
            'imagen_sello' => ['nullable', 'file', 'mimetypes:image/png,image/jpeg', 'max:512', 'dimensions:max_width=2000,max_height=2000'],
        ]);
        $images = [];
        foreach ($files as $key => $file) {
            if ($file !== null) {
                $images[$key] = 'data:'.$file->getMimeType().';base64,'.base64_encode($file->get());
            }
        }

        return $images;
    }

    private function signatureStrokes(Request $request): ?array
    {
        $signature = $request->input('firma');
        if ($signature === null) {
            return null;
        }

        if (is_string($signature) && strlen($signature) <= 30000
            && (! $request->is('api/*') || str_starts_with((string) $request->header('Content-Type'), 'multipart/form-data'))) {
            $signature = json_decode($signature, true, 5);
        }

        $invalid = fn () => ValidationException::withMessages(['firma' => 'La firma debe contener un trazo válido.']);
        if (! is_array($signature) || ! array_is_list($signature) || count($signature) > 32) {
            throw $invalid();
        }

        $points = 0;
        $hasStroke = false;
        foreach ($signature as $stroke) {
            if (! is_array($stroke) || ! array_is_list($stroke) || $stroke === [] || ($points += count($stroke)) > 2000) {
                throw $invalid();
            }
            foreach ($stroke as $point) {
                if (! is_array($point) || array_keys($point) !== [0, 1]
                    || ! is_int($point[0]) || ! is_int($point[1])
                    || min($point) < 0 || max($point) > 1000) {
                    throw $invalid();
                }
                $hasStroke = $hasStroke || $point !== $stroke[0];
            }
        }

        if (! $hasStroke) {
            throw $invalid();
        }

        return $signature;
    }

    private function currentSenderSignature(): array
    {
        return ['senderSignatures as current_sender_signed' => fn ($signature) => $signature
            ->whereColumn('note_version', 'internal_notes.version')->whereColumn('user_id', 'internal_notes.author_id')];
    }

    private function visibleNotes(User $actor): Builder
    {
        return InternalNote::visibleTo($actor)->withExists($this->currentSenderSignature())
            ->with(['origin', 'recipient', 'participants', 'document.sheet.currentUnit', 'document.sheet.pendingUnit']);
    }

    private function find(User $actor, string $id): InternalNote
    {
        return $this->visibleNotes($actor)->findOrFail($id);
    }

    private function canEdit(InternalNote $note, User $actor): bool
    {
        return $note->state === InternalNote::DRAFT && $note->author_id === $actor->id && $note->origin_unit_id === $actor->unit_id;
    }

    private function form(User $actor, InternalNote $note)
    {
        $units = Unit::where('institution_id', $actor->unit->institution_id)->where('enabled', true)->orderBy('name');
        $accounts = User::where('enabled', true)->whereIn('unit_id', (clone $units)->reorder()->select('id'))->with('unit')->orderBy('name')->get();

        return view('internal-notes.form', ['note' => $note, 'units' => $units->get(), 'accounts' => $accounts]);
    }

    private function result(Request $request, InternalNote $note, string $message, int $status = 200)
    {
        if ($request->is('api/*')) {
            $note->loadExists($this->currentSenderSignature());

            return response()->json($this->payload($note->loadMissing('origin', 'recipient', 'participants.user', 'author'), $request->user(), true), $status);
        }

        return redirect()->route('notes.show', $note)->with('status', $message);
    }

    private function payload(InternalNote $note, User $actor, bool $detail = false): array
    {
        $sheet = $note->document?->sheet;
        $actions = [];
        $signatureState = null;
        if ($this->canEdit($note, $actor)) {
            [$signatureState, $action] = match (true) {
                (bool) $note->current_sender_signed => ['firmada', 'emitir'],
                $note->signature_requested_at !== null => ['pendiente', 'firmar_borrador'],
                default => ['sin_solicitar', 'enviar_a_firma'],
            };
            $actions = ['editar_borrador', $action];
        } elseif ($note->state === InternalNote::EMITTING && $note->author_id === $actor->id && $note->origin_unit_id === $actor->unit_id) {
            $actions = ['emitir'];
        } elseif ($note->state === InternalNote::REVIEW && $note->participants->contains(fn ($via) => $via->role === 'via'
            && $via->position === $note->active_position && $via->user_id === $actor->id)) {
            $actions = ['dar_conformidad'];
        } elseif ($note->state === InternalNote::RECEIVE && $note->allowsInitialReceipt($actor)) {
            $actions = ['confirmar_primera_recepcion'];
        } elseif ($sheet?->canReceive($actor)) {
            $actions = ['confirmar_recepcion_derivacion'];
        } elseif ($sheet?->canAttend($actor)) {
            $actions = ['registrar_atencion', 'derivar', 'responder', 'cerrar'];
        }

        $origin = ['id' => $note->origin->id, 'nombre' => $note->origin->name];
        $data = [
            'id' => $note->id,
            'asunto' => $note->subject,
            'unidad_origen' => $origin,
            'unidad_destinataria' => ['id' => $note->recipient->id, 'nombre' => $note->recipient->name],
            'estado_firma' => $signatureState,
            'version' => $note->version,
            'fecha_ultimo_movimiento' => ($sheet?->updated_at ?? $note->updated_at)->toISOString(),
            'documento_id' => $note->document_id,
            'hoja_id' => $sheet?->id,
            'acciones_permitidas' => $actions,
        ] + $this->routeSummary($note);

        if ($detail) {
            $data['seguimiento'] = $this->progress($note, $data);
            $data['autor'] = ['id' => $note->author->id, 'nombre' => $note->author->name];
            $data['referencia'] = $note->reference;
            $data['cuerpo'] = $note->body;
            $data['sello_recepcion'] = $note->receiptStamp();
            $data['constancias'] = $this->signatureReceipts($note);
            $count = $note->participants->where('role', 'via')->count();
            $data['movimientos_nota'] = $note->participants->whereNotNull('confirmed_at')->values()->map(fn ($via) => [
                'id' => $via->id,
                'accion' => 'conformidad',
                'actor' => ['id' => $via->user_id, 'nombre' => $via->user->name],
                'fecha' => $via->confirmed_at->toISOString(),
                'estado_resultante' => $via->position === $count ? InternalNote::RECEIVE : InternalNote::REVIEW,
            ])->all();
            if ($note->emitted_at !== null) {
                array_unshift($data['movimientos_nota'], [
                    'id' => $note->id,
                    'accion' => 'emision',
                    'actor' => ['id' => $note->author_id, 'nombre' => $note->author->name],
                    'fecha' => $note->emitted_at->toISOString(),
                    'estado_resultante' => $count === 0 ? InternalNote::RECEIVE : InternalNote::REVIEW,
                ]);
            }
        }

        return $data;
    }

    private function signatureReceipts(InternalNote $note): array
    {
        $confirmed = $note->participants->where('role', 'via')->whereNotNull('confirmed_at')->keyBy('user_id');

        return $note->signatures()->with(['user:id,name', 'unit:id,name'])
            ->orderBy('signed_at')->orderBy('id')
            ->get(['id', 'user_id', 'unit_id', 'action', 'note_version', 'signed_at'])
            ->filter(fn (InternalNoteSignature $signature) => match ($signature->action) {
                InternalNoteSignature::SENDER => $signature->user_id === $note->author_id
                    && $signature->note_version === ($note->emission_version ?? $note->version),
                InternalNoteSignature::VIA => isset($confirmed[$signature->user_id])
                    && $confirmed[$signature->user_id]->action_version === $signature->note_version,
                default => false,
            })
            ->map(fn (InternalNoteSignature $signature) => [
                'tipo' => 'firma', 'accion' => $signature->action, 'version' => $signature->note_version,
                'actor' => ['nombre' => $signature->user->name],
                'unidad' => ['nombre' => $signature->unit->name],
                'fecha' => $signature->signed_at->toISOString(),
            ])->values()->all();
    }

    private function routeSummary(InternalNote $note): array
    {
        $sheet = $note->document?->sheet;
        $current = $sheet?->currentUnit ?? $note->origin;
        $pending = $sheet === null && $note->state === InternalNote::RECEIVE ? $note->recipient : $sheet?->pendingUnit;

        return [
            'cite' => $note->cite,
            'estado' => $note->displayState(),
            'etiqueta_estado' => $note->stateLabel(),
            'unidad_actual' => ['id' => $current->id, 'nombre' => $current->name],
            'destino_pendiente' => $pending ? ['id' => $pending->id, 'nombre' => $pending->name] : null,
        ];
    }

    private function progress(InternalNote $note, array $summary): array
    {
        $unit = $summary['unidad_actual'];
        $label = $summary['etiqueta_estado'];
        $stage = match ($summary['estado']) {
            InternalNote::REVIEW => 'revision',
            InternalNote::RECEIVE, InternalNote::RECEIVED => 'recepcion',
            'en_atencion' => 'atencion',
            'cerrada' => 'cierre',
            default => 'preparacion',
        };

        if ($stage === 'revision') {
            $active = $note->participants->where('role', 'via')->firstWhere('position', $note->active_position);
            $reviewUnit = $active?->user?->unit;
            if ($reviewUnit !== null) {
                $unit = ['id' => $reviewUnit->id, 'nombre' => $reviewUnit->name];
            }
            $label = 'Pendiente de revisión VÍA';
        } elseif ($summary['destino_pendiente'] !== null) {
            $unit = $summary['destino_pendiente'];
            if ($note->document?->sheet !== null) {
                $label = 'Recepción por derivación pendiente';
            }
        }

        return ['etapa' => $stage, 'etiqueta' => $label, 'unidad' => $unit];
    }
}
