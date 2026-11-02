<?php

return [
    'disk' => 'attachments',

    'cipher' => 'AES-256-CBC',

    'active_key_version' => 'v1',

    'keys' => [
        'v1' => env('ATTACHMENTS_KEY_V1'),
    ],
];
