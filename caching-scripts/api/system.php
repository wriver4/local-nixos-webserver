<?php
// System Scripts Management API
// This script provides safe execution of system-level cache management scripts

header('Content-Type: application/json');

// Security check - only allow access from admin panel
session_start();
if (!isset($_SESSION['cache_admin_logged_in']) || $_SESSION['cache_admin_logged_in'] !== true) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Access denied']);
    exit;
}

$action = $_POST['action'] ?? $_GET['action'] ?? '';
$response = ['success' => false, 'message' => '', 'data' => null];

// Define allowed scripts and their parameters
$allowed_scripts = [
    'manage-hosts' => [
        'path' => '/usr/local/bin/manage-hosts',
        'actions' => ['add', 'remove', 'list', 'backup', 'restore'],
        'requires_param' => ['add', 'remove', 'restore']
    ],
    'monitor-hosts' => [
        'path' => '/usr/local/bin/monitor-hosts',
        'actions' => [],
        'requires_param' => []
    ],
    'create-site-db' => [
        'path' => '/usr/local/bin/create-site-db',
        'actions' => [],
        'requires_param' => [true] // Always requires database name
    ],
    'create-site-dir' => [
        'path' => '/usr/local/bin/create-site-dir',
        'actions' => [],
        'requires_param' => [true] // Always requires domain and site name
    ],
    'rebuild-webserver' => [
        'path' => '/usr/local/bin/rebuild-webserver',
        'actions' => [],
        'requires_param' => []
    ]
];

function executeScript($script_name, $params = []) {
    global $allowed_scripts;
    
    if (!isset($allowed_scripts[$script_name])) {
        return ['success' => false, 'message' => 'Script not allowed'];
    }
    
    $script_config = $allowed_scripts[$script_name];
    $command = $script_config['path'];
    
    // Add parameters
    foreach ($params as $param) {
        $command .= ' ' . escapeshellarg($param);
    }
    
    // Execute command and capture output
    $output = shell_exec($command . ' 2>&1');
    $exit_code = 0;
    
    // Check if command was successful (basic check)
    if ($output === null) {
        return ['success' => false, 'message' => 'Failed to execute script'];
    }
    
    // Log the action
    $log_entry = date('Y-m-d H:i:s') . " - Admin: " . $_SESSION['cache_admin_username'] . " - Executed: $command\n";
    file_put_contents('/var/log/caching-scripts/activity.log', $log_entry, FILE_APPEND | LOCK_EX);
    
    return [
        'success' => true,
        'message' => 'Script executed successfully',
        'output' => $output,
        'command' => $command
    ];
}

switch ($action) {
    case 'execute':
        $script = $_POST['script'] ?? '';
        $script_action = $_POST['script_action'] ?? '';
        $params = [];
        
        if (empty($script)) {
            $response = ['success' => false, 'message' => 'Script name is required'];
            break;
        }
        
        // Handle different script types
        switch ($script) {
            case 'manage-hosts':
                $hosts_action = $_POST['hosts_action'] ?? '';
                if (empty($hosts_action)) {
                    $response = ['success' => false, 'message' => 'Hosts action is required'];
                    break 2;
                }
                
                $params[] = $hosts_action;
                
                if (in_array($hosts_action, ['add', 'remove'])) {
                    $domain = $_POST['domain'] ?? '';
                    if (empty($domain)) {
                        $response = ['success' => false, 'message' => 'Domain is required'];
                        break 2;
                    }
                    $params[] = $domain;
                } elseif ($hosts_action === 'restore') {
                    $backup_file = $_POST['backup_file'] ?? '';
                    if (empty($backup_file)) {
                        $response = ['success' => false, 'message' => 'Backup file is required'];
                        break 2;
                    }
                    $params[] = $backup_file;
                }
                break;
                
            case 'create-site-db':
                $db_name = $_POST['db_name'] ?? '';
                if (empty($db_name)) {
                    $response = ['success' => false, 'message' => 'Database name is required'];
                    break 2;
                }
                $params[] = $db_name;
                break;
                
            case 'create-site-dir':
                $domain = $_POST['domain'] ?? '';
                $site_name = $_POST['site_name'] ?? '';
                
                if (empty($domain) || empty($site_name)) {
                    $response = ['success' => false, 'message' => 'Domain and site name are required'];
                    break 2;
                }
                
                $params[] = $domain;
                $params[] = $site_name;
                break;
                
            case 'monitor-hosts':
            case 'rebuild-webserver':
                // No additional parameters needed
                break;
                
            default:
                $response = ['success' => false, 'message' => 'Unknown script'];
                break 2;
        }
        
        $response = executeScript($script, $params);
        break;
        
    case 'list_scripts':
        $scripts = [];
        foreach ($allowed_scripts as $name => $config) {
            $scripts[] = [
                'name' => $name,
                'path' => $config['path'],
                'actions' => $config['actions'],
                'requires_param' => $config['requires_param']
            ];
        }
        
        $response = [
            'success' => true,
            'message' => 'Available scripts listed',
            'data' => $scripts
        ];
        break;
        
    case 'get_logs':
        $log_file = '/var/log/caching-scripts/activity.log';
        $lines = intval($_POST['lines'] ?? $_GET['lines'] ?? 50);
        
        if (file_exists($log_file)) {
            $log_content = shell_exec("tail -n $lines " . escapeshellarg($log_file));
            $response = [
                'success' => true,
                'message' => 'Log retrieved',
                'data' => $log_content
            ];
        } else {
            $response = ['success' => false, 'message' => 'Log file not found'];
        }
        break;
        
    case 'check_script_status':
        $script = $_POST['script'] ?? $_GET['script'] ?? '';
        
        if (empty($script) || !isset($allowed_scripts[$script])) {
            $response = ['success' => false, 'message' => 'Invalid script'];
            break;
        }
        
        $script_path = $allowed_scripts[$script]['path'];
        $exists = file_exists($script_path);
        $executable = $exists ? is_executable($script_path) : false;
        
        $response = [
            'success' => true,
            'message' => 'Script status checked',
            'data' => [
                'script' => $script,
                'path' => $script_path,
                'exists' => $exists,
                'executable' => $executable,
                'status' => $exists && $executable ? 'ready' : 'not_available'
            ]
        ];
        break;
        
    default:
        $response = ['success' => false, 'message' => 'Invalid action'];
        break;
}

echo json_encode($response);
?>
