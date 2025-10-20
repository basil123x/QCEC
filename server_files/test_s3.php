<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

echo json_encode([
    'success' => true,
    'message' => 'Test endpoint working',
    'server_info' => [
        'php_version' => phpversion(),
        'current_dir' => getcwd(),
        'files_in_dir' => scandir('.'),
        'parent_files' => file_exists('..') ? scandir('..') : 'Cannot access parent'
    ]
], JSON_UNESCAPED_UNICODE);
?>
