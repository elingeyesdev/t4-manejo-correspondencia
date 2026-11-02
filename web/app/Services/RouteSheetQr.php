<?php

namespace App\Services;

use App\Models\RouteSheet;
use Endroid\QrCode\Encoding\Encoding;
use Endroid\QrCode\ErrorCorrectionLevel;
use Endroid\QrCode\QrCode;
use Endroid\QrCode\Writer\SvgWriter;

class RouteSheetQr
{
    public function content(RouteSheet $sheet): string
    {
        return route('route-sheets.show', [
            'reference' => $sheet->id,
        ]);
    }

    public function svg(RouteSheet $sheet): string
    {
        $qr = new QrCode(
            data: $this->content($sheet),
            encoding: new Encoding('UTF-8'),
            errorCorrectionLevel: ErrorCorrectionLevel::Medium,
            size: 320,
            margin: 48,
        );

        return (new SvgWriter)->write($qr)->getString();
    }
}
