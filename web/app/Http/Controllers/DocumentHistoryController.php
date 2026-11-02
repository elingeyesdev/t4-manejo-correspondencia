<?php

namespace App\Http\Controllers;

use App\Services\DocumentHistory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DocumentHistoryController extends Controller
{
    public function show(
        Request $request,
        string $id,
        DocumentHistory $history
    ): JsonResponse {
        return response()->json(
            $history->execute($request->user(), $id),
            200,
            ['Cache-Control' => 'private, no-store']
        );
    }
}
