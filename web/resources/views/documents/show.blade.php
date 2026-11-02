@extends('layout')
@section('title', 'Detalle de correspondencia')
@section('content')
    @php
        $actorIds = $document->sheet->movements->pluck('actor_id')->push($payload['hoja']['responsable_id'])->unique();
        $actorNames = \App\Models\User::whereIn('id', $actorIds)->pluck('name', 'id');
        $detailProps = [
            'document' => [
                'code' => $document->code, 'guide' => $document->guide,
                'subject' => $document->subject, 'sender' => $document->sender,
                'receivedOn' => $document->received_on->format('d/m/Y'),
                'unit' => $document->unit->name, 'type' => $document->type->name,
                'priority' => $document->priority->name,
            ],
            'sheet' => [
                'code' => $payload['hoja']['codigo'], 'state' => $payload['estado'],
                'version' => $payload['hoja']['version'],
                'responsible' => $actorNames[$payload['hoja']['responsable_id']] ?? 'No disponible',
            ],
            'movements' => $document->sheet->movements->sortBy('occurred_at')->map(fn ($event) => [
                'id' => $event->id, 'action' => $event->action,
                'actor' => $actorNames[$event->actor_id] ?? 'No disponible',
                'date' => $event->occurred_at->timezone('America/La_Paz')->format('d/m/Y H:i:s'),
                'state' => $event->resulting_state,
            ])->values()->all(),
            'indexUrl' => route('documents.index'),
        ];
    @endphp
    <div id="document-detail" data-props="{{ json_encode($detailProps, JSON_UNESCAPED_SLASHES) }}"></div>
@endsection
