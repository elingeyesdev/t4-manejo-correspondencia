<?php

namespace App\Providers;

use App\Models\NoteNotice;
use Illuminate\Support\Facades\View;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        View::composer('layout', function (\Illuminate\View\View $view): void {
            $actor = auth()->user();
            if ($actor?->isOperational()) {
                $view->with('unreadNoticeCount', NoteNotice::visibleTo($actor)->whereNull('read_at')->count());
            }
        });
    }
}
