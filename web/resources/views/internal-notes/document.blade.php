<!doctype html>
<html lang="es-BO">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
    <title>{{ $note->cite ?? 'Borrador de nota interna' }}</title>
    <style>
        @page {
            size: letter;
            margin: 39mm 0 33mm;
            @top-center {
                content: "";
                width: 215.9mm;
                height: 39mm;
                background: url("data:image/jpeg;base64,{{ $letterhead }}") center top / 215.9mm 279.4mm no-repeat;
            }
            @bottom-center {
                content: "";
                width: 215.9mm;
                height: 33mm;
                background: url("data:image/jpeg;base64,{{ $letterhead }}") center bottom / 215.9mm 279.4mm no-repeat;
            }
        }
        * { box-sizing: border-box; }
        html { print-color-adjust: exact; -webkit-print-color-adjust: exact; }
        body { margin: 0; color: #161616; font: 12pt/1.28 "Times New Roman", "Liberation Serif", serif; }
        .hoja { width: 215.9mm; min-height: 279.4mm; margin: 0 auto; padding: 39mm 20mm 33mm 30mm; position: relative; }
        .membrete { position: absolute; inset: 0 auto auto 0; width: 215.9mm; height: 279.4mm; z-index: -1; }
        .cite { font-weight: bold; text-decoration: underline; }
        .fecha { margin: 0 0 5mm; }
        dl { margin: 0; }
        .campo { display: flex; gap: 1mm; margin: 0 0 4mm; break-inside: avoid; }
        dt { flex: 0 0 23mm; font-weight: bold; }
        dd { margin: 0; flex: 1; overflow-wrap: anywhere; }
        .cargo, .ref dd { font-weight: bold; text-transform: uppercase; }
        .ref { border-bottom: 1px solid; padding-bottom: 2mm; margin-bottom: 3mm; }
        .cuerpo { clear: both; white-space: pre-wrap; text-align: justify; overflow-wrap: anywhere; margin: 0 0 8mm; }
        .constancia { break-inside: avoid; margin: 0 0 4mm; text-align: center; font-size: 9pt; }
        .imagen, .trazo { display: inline-block; width: 36mm; height: 15mm; object-fit: contain; vertical-align: middle; }
        .recibido { float: right; width: 47mm; margin: 0 0 3mm 4mm; border: 1pt solid #174377; color: #174377; text-align: center; padding: 2mm; font-size: 9pt; break-inside: avoid; overflow-wrap: anywhere; }
        .recibido strong { display: block; font-size: 12pt; }
        .provisional { border: 1pt dashed #6e5a3f; padding: 2mm; }
        @media screen and (max-width: 815px) {
            .hoja { width: 100%; min-height: min(279.4mm, 129vw); padding: 18vw 7vw 17vw; }
            .membrete { width: 100%; height: auto; }
            dt { flex-basis: 12vw; }
            .recibido { max-width: 45%; }
        }
        @media print {
            .hoja { width: auto; min-height: auto; padding: 0 20mm 0 30mm; margin: 0; }
            .membrete { display: none; }
            .hoja::before {
                content: "";
                position: fixed;
                inset: 0 0 auto;
                height: 207.4mm;
                background: url("data:image/jpeg;base64,{{ $letterhead }}") center -39mm / 215.9mm 279.4mm no-repeat;
                z-index: -1;
            }
        }
    </style>
</head>
<body>
<article class="hoja">
    <img class="membrete" src="data:image/jpeg;base64,{{ $letterhead }}" alt="">
    @php
        $previewReceipt = ($preview['action'] ?? null) === 'confirmar_primera_recepcion';
    @endphp
    @if ($stamp || $previewReceipt)
        <aside class="recibido">
            @if ($stamp)
                <strong>RECIBIDO</strong>
                <div>{{ \Illuminate\Support\Carbon::parse($stamp['fecha_hora'])->timezone('America/La_Paz')->format('d/m/Y H:i') }}</div>
                <div>{{ $stamp['unidad'] }}</div>
                <div>{{ $stamp['funcionario'] }}</div>
            @else
                <strong>Recepción sin confirmar</strong>
                <div>{{ $preview['unit'] }}</div>
                <div>{{ $preview['name'] }}</div>
            @endif
            @include('internal-notes.document-marks', ['strokes' => [], 'images' => ($stamp ? $note->receipt_images : $preview['images']) ?? []])
        </aside>
    @endif
    <div class="cite">{{ $note->cite ?? 'BORRADOR' }}</div>
    <p class="fecha">Santa Cruz de la Sierra, {{ ($note->emitted_at ?? $note->created_at)->copy()->timezone('America/La_Paz')->locale('es')->translatedFormat('j \d\e F \d\e Y') }}</p>
    <dl>
        <div class="campo"><dt>A</dt><dd class="cargo">{{ $heading['recipient'] ?? 'Unidad por seleccionar' }}</dd></div>
        @foreach (['via' => 'VÍA', 'cc' => 'CC'] as $role => $label)
            @foreach (collect($heading['people'])->where('role', $role) as $person)
                <div class="campo">
                    <dt>{{ $label }}</dt>
                    <dd>{{ $person['name'] }}<br><span class="cargo">{{ $person['unit'] }}</span></dd>
                </div>
            @endforeach
        @endforeach
        <div class="campo"><dt>DE</dt><dd>{{ $heading['sender']['name'] }}<br><span class="cargo">{{ $heading['sender']['unit'] }}</span></dd></div>
        <div class="campo ref"><dt>REF.</dt><dd>{{ $note->reference ?: $note->subject }}</dd></div>
    </dl>
    @if ($note->reference && $note->reference !== $note->subject)
        <p><strong>{{ $note->subject }}</strong></p>
    @endif
    <div class="cuerpo">{{ $note->body }}</div>
    @foreach ($signatures as $signature)
        @php
            $mark = $signature->strokes;
            $images = $mark['images'] ?? [];
            $strokes = $mark['strokes'] ?? (array_is_list($mark) ? $mark : []);
            $signer = $signature->action === 'firma_remitente' ? $heading['sender']
                : (collect($heading['people'])->first(fn ($person) => $person['role'] === 'via' && $person['id'] === $signature->user_id)
                    ?? ['name' => $signature->user->name, 'unit' => $signature->unit->name]);
        @endphp
        <div class="constancia">
            @include('internal-notes.document-marks', compact('strokes', 'images'))
            <div><strong>{{ $signer['name'] }}</strong> · {{ $signer['unit'] }}</div>
            <div>{{ $signature->action === 'conformidad_via' ? 'Conformidad VÍA' : 'Remitente' }} · {{ $signature->signed_at->copy()->timezone('America/La_Paz')->format('d/m/Y H:i') }}</div>
        </div>
    @endforeach
    @if ($preview && ! $previewReceipt)
        <div class="constancia provisional">
            @include('internal-notes.document-marks', ['strokes' => $preview['strokes'], 'images' => $preview['images']])
            <div><strong>{{ $preview['name'] }}</strong> · {{ $preview['unit'] }}</div>
            <div>Vista previa de constancias · Sin confirmar</div>
        </div>
    @endif
</article>
</body>
</html>
