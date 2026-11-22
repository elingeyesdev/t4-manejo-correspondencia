<?php

return [
    'credentials_path' => env('GOOGLE_APPLICATION_CREDENTIALS'),
    'project_id' => env('FCM_PROJECT_ID'),
    'android_channel' => env('FCM_ANDROID_CHANNEL', 'correspondencia'),
];
