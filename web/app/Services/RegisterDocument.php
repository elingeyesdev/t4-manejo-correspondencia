<?php

namespace App\Services;

use App\Models\Catalog;
use App\Models\Document;
use App\Models\Movement;
use App\Models\RouteSheet;
use App\Models\Unit;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class RegisterDocument
{
    public function execute(User $actor, array $data): array
    {
        $fields = ['remitente' => (string) $data['remitente'], 'asunto' => (string) $data['asunto'], 'fecha' => (string) $data['fecha'],
            'tipo_id' => (int) $data['tipo_id'], 'prioridad_id' => (int) $data['prioridad_id'], 'unidad_id' => (int) $data['unidad_id']];
        $fingerprint = hash('sha256', json_encode($fields, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR));

        return DB::transaction(function () use ($actor, $data, $fields, $fingerprint) {
            // Serializa registros del mismo actor para reconocer solicitudes concurrentes.
            $actor = User::lockForUpdate()->findOrFail($actor->id);
            abort_unless($actor->isOperational() && $actor->canRegister(), 403);
            abort_unless($actor->isAdmin() || $actor->unit_id === $fields['unidad_id'], 403);
            $previous = DB::table('requests')->where(['actor_id' => $actor->id, 'operation' => 'registro', 'key' => $data['request_key']])->first();
            if ($previous) {
                abort_unless(hash_equals($previous->fingerprint, $fingerprint), 409, 'La clave ya fue utilizada con otros datos.');

                return [Document::visibleTo($actor)->findOrFail($previous->document_id), false];
            }
            $unit = Unit::whereKey($fields['unidad_id'])->lockForUpdate()->firstOrFail();
            if (! $unit->enabled) {
                throw ValidationException::withMessages(['unidad_id' => 'La unidad está deshabilitada.']);
            }
            foreach (['tipo_id' => 'tipo', 'prioridad_id' => 'prioridad'] as $field => $kind) {
                $catalog = Catalog::whereKey($fields[$field])->where('kind', $kind)->lockForUpdate()->firstOrFail();
                if (! $catalog->enabled) {
                    throw ValidationException::withMessages([$field => 'El catálogo está deshabilitado.']);
                }
            }
            $instant = now();
            $suffix = Str::ulid()->toString();
            $doc = Document::create(['id' => (string) Str::uuid(), 'code' => 'DOC-'.$instant->year.'-'.$suffix,
                'guide' => 'COR-'.$instant->year.'-'.$suffix, 'sender' => $fields['remitente'], 'subject' => $fields['asunto'],
                'received_on' => $fields['fecha'], 'type_id' => $fields['tipo_id'], 'priority_id' => $fields['prioridad_id'],
                'unit_id' => $unit->id, 'created_by' => $actor->id]);
            $sheet = RouteSheet::create(['id' => (string) Str::uuid(), 'code' => 'HR-'.$instant->year.'-'.$suffix,
                'document_id' => $doc->id, 'state' => 'REGISTRADA', 'responsible_id' => $actor->id, 'version' => 1]);
            Movement::create(['id' => (string) Str::uuid(), 'route_sheet_id' => $sheet->id, 'actor_id' => $actor->id,
                'origin_unit_id' => $actor->unit_id, 'destination_unit_id' => $unit->id, 'action' => 'REGISTRO', 'resulting_state' => 'REGISTRADA', 'occurred_at' => $instant]);
            DB::table('requests')->insert(['actor_id' => $actor->id, 'operation' => 'registro', 'key' => $data['request_key'],
                'fingerprint' => $fingerprint, 'document_id' => $doc->id, 'created_at' => $instant]);
            DB::table('audits')->insert(['actor_id' => $actor->id, 'action' => 'documento.registrar', 'resource' => $doc->id, 'occurred_at' => $instant]);

            return [$doc, true];
        }, 3);
    }
}
