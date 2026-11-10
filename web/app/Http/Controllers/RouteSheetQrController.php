<?php

namespace App\Http\Controllers;

use App\Models\RouteSheet;
use App\Services\RouteSheetQr;
use Illuminate\Http\Request;

class RouteSheetQrController extends Controller
{
    public function show(Request $request, string $reference)
    {
        $sheet = $this->visibleSheet($request, $reference);
        $document = $sheet->document;

        if ($request->is('api/*')) {
            return response()
                ->json($document->detailPayload($request->user()))
                ->header('Cache-Control', 'private, no-store');
        }

        return redirect()
            ->route('documents.show', $document->id)
            ->header('Cache-Control', 'private, no-store');
    }

    public function image(
        Request $request,
        string $reference,
        RouteSheetQr $qr
    ) {
        $sheet = $this->visibleSheet($request, $reference);

        return response($qr->svg($sheet), 200, [
            'Content-Type' => 'image/svg+xml',
            'Cache-Control' => 'private, no-store',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }

    private function visibleSheet(
        Request $request,
        string $reference
    ): RouteSheet {
        return RouteSheet::visibleTo($request->user())
            ->with('document')
            ->findOrFail($reference);
    }
}
