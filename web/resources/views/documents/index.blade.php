@extends('layout')

@section('title', 'Documentos')

@section('content')
    @php
        $tableProps = [
            'records' => $documents->getCollection()->map(fn ($doc) => [
                'id' => $doc->id,
                'code' => $doc->code,
                'guide' => $doc->guide,
                'subject' => $doc->subject,
                'sender' => $doc->sender,
                'unit' => $doc->unit->name,
                'state' => $doc->sheet->state,
                'detailUrl' => route('documents.show', $doc->id),
            ])->values()->all(),
            'total' => $documents->total(),
            'pageSize' => $documents->perPage(),
            'currentPage' => $documents->currentPage(),
            'canRegister' => auth()->user()->canRegister(),
            'createUrl' => route('documents.create'),
        ];
    @endphp

    <div
        id="documents-table"
        data-props="{{ json_encode($tableProps, JSON_UNESCAPED_SLASHES) }}"
    ></div>
@endsection
