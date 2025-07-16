<?php
// OPcache Management Script
// This script provides programmatic access to OPcache functions

header('Content-Type: application/json');

// Security check - only allow access from admin panel
session_start();
if (!isset($_SESSION['admin_logged_in']) || $_SESSION['admin_logged_in'] !== true) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Access denied']);
    exit;
}

$action = $_POST['action'] ?? $_GET['action'] ?? '';
$response = ['success' => false, 'message' => '', 'data' => null];

switch ($action) {
    case 'status':
        if (function_exists('opcache_get_status')) {
            $status = opcache_get_status();
            if ($status) {
                $stats = $status['opcache_statistics'];
                $memory = $status['memory_usage'];
                
                $hits = $stats['hits'];
                $misses = $stats['misses'];
                $total = $hits + $misses;
                $hit_rate = $total > 0 ? ($hits / $total) * 100 : 0;
                
                $used_memory = $memory['used_memory'];
                $free_memory = $memory['free_memory'];
                $wasted_memory = $memory['wasted_memory'];
                $total_memory = $used_memory + $free_memory + $wasted_memory;
                $memory_usage = $total_memory > 0 ? ($used_memory / $total_memory) * 100 : 0;
                
                $response = [
                    'success' => true,
                    'message' => 'OPcache status retrieved',
                    'data' => [
                        'enabled' => true,
                        'hit_rate' => round($hit_rate, 2),
                        'hits' => $hits,
                        'misses' => $misses,
                        'cached_scripts' => $stats['num_cached_scripts'],
                        'memory_usage' => round($memory_usage, 2),
                        'used_memory' => $used_memory,
                        'free_memory' => $free_memory,
                        'wasted_memory' => $wasted_memory,
                        'total_memory' => $total_memory,
                        'last_restart_time' => $stats['last_restart_time'],
                        'oom_restarts' => $stats['oom_restarts'],
                        'hash_restarts' => $stats['hash_restarts'],
                        'manual_restarts' => $stats['manual_restarts']
                    ]
                ];
            } else {
                $response = ['success' => false, 'message' => 'OPcache is disabled'];
            }
        } else {
            $response = ['success' => false, 'message' => 'OPcache extension not available'];
        }
        break;
        
    case 'reset':
        if (function_exists('opcache_reset')) {
            if (opcache_reset()) {
                $response = ['success' => true, 'message' => 'OPcache reset successfully'];
                
                // Log the action
                $log_entry = date('Y-m-d H:i:s') . " - Admin: " . $_SESSION['admin_username'] . " - OPcache reset\n";
                file_put_contents('/var/log/webserver-dashboard/cache-management.log', $log_entry, FILE_APPEND | LOCK_EX);
            } else {
                $response = ['success' => false, 'message' => 'Failed to reset OPcache'];
            }
        } else {
            $response = ['success' => false, 'message' => 'OPcache reset function not available'];
        }
        break;
        
    case 'invalidate':
        $file = $_POST['file'] ?? $_GET['file'] ?? '';
        if (empty($file)) {
            $response = ['success' => false, 'message' => 'File path is required'];
        } elseif (function_exists('opcache_invalidate')) {
            if (opcache_invalidate($file, true)) {
                $response = ['success' => true, 'message' => "File invalidated: $file"];
                
                // Log the action
                $log_entry = date('Y-m-d H:i:s') . " - Admin: " . $_SESSION['admin_username'] . " - OPcache invalidate: $file\n";
                file_put_contents('/var/log/webserver-dashboard/cache-management.log', $log_entry, FILE_APPEND | LOCK_EX);
            } else {
                $response = ['success' => false, 'message' => "Failed to invalidate: $file"];
            }
        } else {
            $response = ['success' => false, 'message' => 'OPcache invalidate function not available'];
        }
        break;
        
    case 'compile':
        $file = $_POST['file'] ?? $_GET['file'] ?? '';
        if (empty($file)) {
            $response = ['success' => false, 'message' => 'File path is required'];
        } elseif (function_exists('opcache_compile_file')) {
            if (file_exists($file) && opcache_compile_file($file)) {
                $response = ['success' => true, 'message' => "File compiled: $file"];
                
                // Log the action
                $log_entry = date('Y-m-d H:i:s') . " - Admin: " . $_SESSION['admin_username'] . " - OPcache compile: $file\n";
                file_put_contents('/var/log/webserver-dashboard/cache-management.log', $log_entry, FILE_APPEND | LOCK_EX);
            } else {
                $response = ['success' => false, 'message' => "Failed to compile: $file (file may not exist)"];
            }
        } else {
            $response = ['success' => false, 'message' => 'OPcache compile function not available'];
        }
        break;
        
    case 'get_scripts':
        if (function_exists('opcache_get_status')) {
            $status = opcache_get_status();
            if ($status && isset($status['scripts'])) {
                $scripts = [];
                foreach ($status['scripts'] as $file => $info) {
                    $scripts[] = [
                        'file' => $file,
                        'hits' => $info['hits'],
                        'memory_consumption' => $info['memory_consumption'],
                        'last_used_timestamp' => $info['last_used_timestamp'],
                        'timestamp' => $info['timestamp']
                    ];
                }
                
                // Sort by hits (most used first)
                usort($scripts, function($a, $b) {
                    return $b['hits'] - $a['hits'];
                });
                
                $response = [
                    'success' => true,
                    'message' => 'Cached scripts retrieved',
                    'data' => $scripts
                ];
            } else {
                $response = ['success' => false, 'message' => 'No cached scripts found'];
            }
        } else {
            $response = ['success' => false, 'message' => 'OPcache not available'];
        }
        break;
        
    case 'get_configuration':
        if (function_exists('opcache_get_configuration')) {
            $config = opcache_get_configuration();
            $response = [
                'success' => true,
                'message' => 'OPcache configuration retrieved',
                'data' => $config
            ];
        } else {
            $response = ['success' => false, 'message' => 'OPcache configuration not available'];
        }
        break;
        
    default:
        $response = ['success' => false, 'message' => 'Invalid action'];
        break;
}

echo json_encode($response);
?>
