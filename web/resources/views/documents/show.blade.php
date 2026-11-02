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
  'movements' => collect($history['data'])->map(fn ($event) => [
    'id' => $event['id'],
    'action' => $event['accion'],
    'actor' => $event['actor']['nombre'] ?? 'No disponible',
    'originUnit' => $event['unidad_origen']['nombre'] ?? 'No registrada',
    'destinationUnit' => $event['unidad_destino']['nombre'] ?? 'No registrada',
    'date' => \Carbon\CarbonImmutable::parse($event['fecha'])
        ->timezone('America/La_Paz')
        ->format('d/m/Y H:i:s'),
    'state' => $event['estado_resultante'],
    'reason' => $event['motivo'] ?? '—',
])->values()->all(),
        ];
    @endphp
    <div id="document-detail" data-props="{{ json_encode($detailProps, JSON_UNESCAPED_SLASHES) }}"></div>
    @include('documents.attachments')
@endsection
