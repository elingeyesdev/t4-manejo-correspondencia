<?php

namespace App\Http\Controllers;

use App\Models\NoteNotice;
use App\Models\NoteNoticeDevice;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\PersonalAccessToken;
use Throwable;

class NoteNoticeController extends Controller
{
    public function index(Request $request)
    {
        $params = $request->validate(['page' => 'sometimes|integer|min:1', 'per_page' => 'sometimes|integer|between:1,50']);
        $query = NoteNotice::visibleTo($request->user());
        $unread = (clone $query)->whereNull('read_at')->count();
        $page = $query->orderByDesc('created_at')->orderByDesc('id')
            ->paginate($params['per_page'] ?? 15)->withQueryString();

        if (! $request->is('api/*')) {
            return view('note-notices.index', ['notices' => $page, 'unread' => $unread]);
        }

        return response()->json([
            'data' => $page->getCollection()->map(fn (NoteNotice $notice) => $this->payload($notice)),
            'meta' => [
                'current_page' => $page->currentPage(),
                'per_page' => $page->perPage(),
                'last_page' => $page->lastPage(),
                'total' => $page->total(),
            ],
            'no_leidas' => $unread,
        ])->header('Cache-Control', 'private, no-store');
    }

    public function show(Request $request, string $id)
    {
        return response()->json($this->payload(NoteNotice::visibleTo($request->user())->findOrFail($id)))
            ->header('Cache-Control', 'private, no-store');
    }

    public function read(Request $request, string $id)
    {
        $notice = NoteNotice::visibleTo($request->user())->findOrFail($id);
        NoteNotice::visibleTo($request->user())->whereKey($notice->id)->whereNull('read_at')->update(['read_at' => now()]);

        return $request->is('api/*') ? response()->noContent() : redirect()->route('notices.index');
    }

    public function register(Request $request, string $installation)
    {
        $access = $request->user()->currentAccessToken();
        abort_unless($access instanceof PersonalAccessToken, 401);
        $data = $request->validate(['token_fcm' => 'required|string|max:4096', 'plataforma' => 'required|in:android']);
        $installation = strtolower($installation);
        $hash = hash('sha256', $data['token_fcm']);
        $userId = $request->user()->id;

        retry(3, function () use ($installation, $hash, $access, $userId, $data): void {
            DB::transaction(function () use ($installation, $hash, $access, $userId, $data): void {
                NoteNoticeDevice::where('token_hash', $hash)->where('id', '!=', $installation)->delete();
                NoteNoticeDevice::updateOrCreate(['id' => $installation], [
                    'user_id' => $userId,
                    'access_token_id' => $access->id,
                    'token_hash' => $hash,
                    'fcm_token' => $data['token_fcm'],
                ]);
            }, 3);
        }, 10, fn (Throwable $error) => $error instanceof UniqueConstraintViolationException);

        return response()->noContent();
    }

    public function unregister(Request $request, string $installation)
    {
        $access = $request->user()->currentAccessToken();
        abort_unless($access instanceof PersonalAccessToken, 401);
        NoteNoticeDevice::whereKey(strtolower($installation))->where('user_id', $request->user()->id)
            ->where('access_token_id', $access->id)->update(['access_token_id' => null]);

        return response()->noContent();
    }

    private function payload(NoteNotice $notice): array
    {
        return [
            'id' => $notice->id,
            'tipo' => $notice->type,
            'nota_id' => $notice->note_id,
            'creada_en' => $notice->created_at->toISOString(),
            'leida_en' => $notice->read_at?->toISOString(),
        ];
    }
}
