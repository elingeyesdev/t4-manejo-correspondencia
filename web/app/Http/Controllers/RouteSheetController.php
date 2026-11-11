<?php

namespace App\Http\Controllers;

use App\Http\Requests\RouteSheetActionRequest;
use App\Models\RouteSheet;
use App\Services\RouteSheetWorkflow;
use Illuminate\Http\Request;

class RouteSheetController extends Controller
{
    public function destinations(Request $request, string $reference)
    {
        $sheet = RouteSheet::visibleTo($request->user())->with('document.unit')->findOrFail($reference);
        abort_unless($sheet->canDerive($request->user()), 403, 'ACCION_NO_PERMITIDA');

        return response()->json([
            'data' => $sheet->eligibleDestinations()->orderBy('name')->get(['id', 'name'])
                ->map(fn ($unit) => ['id' => $unit->id, 'nombre' => $unit->name]),
        ]);
    }

    public function derive(RouteSheetActionRequest $request, string $reference, RouteSheetWorkflow $workflow)
    {
        [$result, $created] = $workflow->derive($request->user(), $reference, $request->validated());

        return $this->respond($request, $result, $created, 'Hoja derivada.');
    }

    public function receive(RouteSheetActionRequest $request, string $reference, RouteSheetWorkflow $workflow)
    {
        [$result, $created] = $workflow->receive($request->user(), $reference, $request->validated());

        return $this->respond($request, $result, $created, 'Recepción confirmada.');
    }

    public function attend(RouteSheetActionRequest $request, string $reference, RouteSheetWorkflow $workflow)
    {
        [$result, $created] = $workflow->attend($request->user(), $reference, $request->validated());

        return $this->respond($request, $result, $created, 'Atención registrada.');
    }

    private function respond(Request $request, array $result, bool $created, string $message)
    {
        if ($request->routeIs('api.route-sheets.*')) {
            return response()->json($result, $created ? 201 : 200);
        }

        return redirect()->route('documents.show', $result['documento_id'])
            ->with('status', $created ? $message : 'Se recuperó la confirmación anterior.');
    }
}
