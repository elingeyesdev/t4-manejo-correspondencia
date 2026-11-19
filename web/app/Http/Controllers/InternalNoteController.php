<?php

namespace App\Http\Controllers;

use App\Http\Requests\InternalNoteDraftRequest;
use App\Models\Document;
use App\Models\InternalNote;
use App\Models\Unit;
use App\Models\User;
use App\Services\InternalNoteWorkflow;
use App\Services\ReceiveInternalNote;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class InternalNoteController extends Controller
{
    public function index(Request $request)
    {
        $actor = $request->user();
        $api = $request->is('api/*');
        $filters = $request->validate([
            'bandeja' => ['sometimes', Rule::in(['mis_notas', 'por_revisar', 'por_recibir', 'por_atender', 'copias'])],
            'page' => ['sometimes', 'integer', 'min:1'],
            'per_page' => ['sometimes', 'integer', 'min:1', 'max:50'],
        ]);
        $tray = $filters['bandeja'] ?? ($api ? 'por_revisar' : 'mis_notas');
        $query = InternalNote::visibleTo($actor)->with(['origin', 'recipient', 'participants', 'document.sheet.currentUnit', 'document.sheet.pendingUnit']);

        match ($tray) {
            'mis_notas' => $query->where('author_id', $actor->id),
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
        $note->load('document.sheet.movements.actor', 'document.sheet.movements.destinationUnit');

        return view('internal-notes.show', compact('note', 'via', 'data', 'actionKey', 'canOpenSheet'));
    }

    public function store(InternalNoteDraftRequest $request, InternalNoteWorkflow $workflow)
    {
        $note = $workflow->save($request->user(), $request->validated());

        return $this->result($request, $note, 'Borrador guardado.', 201);
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

    public function approve(Request $request, string $id, InternalNoteWorkflow $workflow)
    {
        $data = $this->action($request);
        $note = $workflow->approve($request->user(), $this->find($request->user(), $id), (int) $data['version'], $data['request_key']);
        $pending = $note->participants()->where('role', 'via')->where('user_id', $request->user()->id)->whereNull('confirmed_at')->exists();

        return $this->result($request, $note, $pending ? 'Conformidad pendiente. Puedes reintentar desde esta nota.' : 'Conformidad registrada.', $pending ? 202 : 200);
    }

    public function receive(Request $request, string $id, ReceiveInternalNote $receipt)
    {
        $actor = $request->user();
        $data = $this->action($request);
        $note = $receipt->execute($actor, $this->find($actor, $id), (int) $data['version'], $data['request_key']);
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

    private function find(User $actor, string $id): InternalNote
    {
        return InternalNote::visibleTo($actor)->with(['origin', 'recipient', 'participants', 'document.sheet.currentUnit', 'document.sheet.pendingUnit'])->findOrFail($id);
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
            return response()->json($this->payload($note->loadMissing('origin', 'recipient', 'participants.user', 'author'), $request->user(), true), $status);
        }

        return redirect()->route('notes.show', $note)->with('status', $message);
    }

    private function payload(InternalNote $note, User $actor, bool $detail = false): array
    {
        $sheet = $note->document?->sheet;
        $actions = [];
        if ($this->canEdit($note, $actor)) {
            $actions = ['editar_borrador', 'emitir'];
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
        $current = $sheet?->currentUnit ?? $note->origin;
        $pending = $note->state === InternalNote::RECEIVE ? $note->recipient : $sheet?->pendingUnit;
        $data = [
            'id' => $note->id,
            'cite' => $note->cite,
            'asunto' => $note->subject,
            'unidad_origen' => $origin,
            'unidad_actual' => ['id' => $current->id, 'nombre' => $current->name],
            'destino_pendiente' => $pending ? ['id' => $pending->id, 'nombre' => $pending->name] : null,
            'estado' => $note->displayState(),
            'version' => $note->version,
            'fecha_ultimo_movimiento' => ($sheet?->updated_at ?? $note->updated_at)->toISOString(),
            'documento_id' => $note->document_id,
            'hoja_id' => $sheet?->id,
            'acciones_permitidas' => $actions,
        ];

        if ($detail) {
            $data['referencia'] = $note->reference;
            $data['cuerpo'] = $note->body;
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
}
