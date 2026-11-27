<?php

namespace App\Services;

use App\Models\InternalNote;
use App\Models\InternalNoteSignature;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Str;
use Symfony\Component\Process\Exception\ProcessTimedOutException;
use Symfony\Component\Process\Exception\RuntimeException as ProcessRuntimeException;
use Symfony\Component\Process\Process;

class InstitutionalNoteDocument
{
    public function configured(): bool
    {
        $browser = config('documents.chromium_binary');

        return is_string($browser) && is_file($browser);
    }

    public function html(InternalNote $note, ?array $preview = null): string
    {
        $heading = $note->documentHeading();
        if ($note->exists) {
            $note->loadMissing(['participants', 'signatures.user', 'signatures.unit']);
        }
        $confirmed = $note->participants->where('role', 'via')->whereNotNull('confirmed_at')->keyBy('user_id');
        $signatures = $note->signatures->filter(fn (InternalNoteSignature $signature) => match ($signature->action) {
            InternalNoteSignature::SENDER => $signature->user_id === $note->author_id
                && $signature->note_version === ($note->emission_version ?? $note->version),
            InternalNoteSignature::VIA => $confirmed->get($signature->user_id)?->action_version === $signature->note_version,
            default => false,
        })->sortBy(fn (InternalNoteSignature $signature) => $signature->action === InternalNoteSignature::SENDER
            ? 0 : $confirmed->get($signature->user_id)->position);
        $stamp = $note->receiptStamp();
        $letterhead = base64_encode(File::get(resource_path('membrete-concejo.jpg')));

        return view('internal-notes.document', compact('note', 'heading', 'signatures', 'stamp', 'letterhead', 'preview'))->render();
    }

    public function pdf(InternalNote $note, ?array $preview = null): string
    {
        $browser = config('documents.chromium_binary');
        abort_unless($this->configured(), 503, 'El servidor no tiene habilitada la exportación PDF.');

        // Chromium writes nested profile files. A short temporary path avoids Windows path limits.
        $directory = rtrim(sys_get_temp_dir(), '/\\').DIRECTORY_SEPARATOR.'ni-'.Str::random(16);
        File::makeDirectory($directory, 0700, true);

        try {
            $htmlPath = $directory.'/documento.html';
            File::put($htmlPath, $this->html($note, $preview));
            $segments = explode('/', str_replace('\\', '/', $htmlPath));
            $fileUrl = 'file:///'.ltrim(implode('/', array_map(
                fn (string $part) => preg_match('/^[A-Za-z]:$/D', $part) ? $part : rawurlencode($part),
                $segments,
            )), '/');
            $process = new Process([
                $browser,
                '--headless',
                '--disable-gpu',
                '--disable-background-networking',
                '--disable-extensions',
                '--no-first-run',
                '--user-data-dir='.$directory.'/p',
                '--no-pdf-header-footer',
                '--print-to-pdf='.$directory.'/documento.pdf',
                $fileUrl,
            ], $directory, timeout: 20);
            $process->disableOutput();
            try {
                $process->run();
            } catch (ProcessTimedOutException|ProcessRuntimeException $error) {
                logger()->warning('Chromium no terminó normalmente al exportar una nota.', [
                    'tipo' => $error::class,
                ]);
            }

            $output = $directory.'/documento.pdf';
            $pdf = File::exists($output) ? File::get($output) : '';
            if (! str_starts_with($pdf, '%PDF-') || ! str_ends_with(rtrim($pdf), '%%EOF')) {
                logger()->warning('Chromium no entregó un PDF completo de la nota.', [
                    'salida' => $process->getExitCode(),
                ]);
                abort(503, 'No se pudo exportar el PDF.');
            }

            return $pdf;
        } finally {
            File::deleteDirectory($directory);
        }
    }
}
