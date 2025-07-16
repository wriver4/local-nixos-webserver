<?php
// Redis Management Script
// This script provides programmatic access to Redis functions

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

// Initialize Redis connection
$redis = null;
try {
    if (class_exists('Redis')) {
        $redis = new Redis();
        $redis->connect('127.0.0.1', 6379);
    } else {
        $response = ['success' => false, 'message' => 'Redis extension not available'];
        echo json_encode($response);
        exit;
    }
} catch (Exception $e) {
    $response = ['success' => false, 'message' => 'Redis connection failed: ' . $e->getMessage()];
    echo json_encode($response);
    exit;
}

switch ($action) {
    case 'status':
        try {
            $info = $redis->info();
            
            $hits = intval($info['keyspace_hits'] ?? 0);
            $misses = intval($info['keyspace_misses'] ?? 0);
            $total = $hits + $misses;
            $hit_rate = $total > 0 ? ($hits / $total) * 100 : 0;
            
            // Get database sizes
            $databases = [];
            for ($i = 0; $i < 16; $i++) {
                $redis->select($i);
                $size = $redis->dbSize();
                if ($size > 0) {
                    $databases[$i] = $size;
                }
            }
            
            $response = [
                'success' => true,
                'message' => 'Redis status retrieved',
                'data' => [
                    'connected' => true,
                    'version' => $info['redis_version'] ?? 'Unknown',
                    'uptime' => $info['uptime_in_seconds'] ?? 0,
                    'connected_clients' => $info['connected_clients'] ?? 0,
                    'used_memory' => $info['used_memory'] ?? 0,
                    'used_memory_human' => $info['used_memory_human'] ?? '0B',
                    'maxmemory' => $info['maxmemory'] ?? 0,
                    'maxmemory_policy' => $info['maxmemory_policy'] ?? 'noeviction',
                    'hit_rate' => round($hit_rate, 2),
                    'hits' => $hits,
                    'misses' => $misses,
                    'databases' => $databases,
                    'total_commands_processed' => $info['total_commands_processed'] ?? 0,
                    'instantaneous_ops_per_sec' => $info['instantaneous_ops_per_sec'] ?? 0
                ]
            ];
        } catch (Exception $e) {
            $response = ['success' => false, 'message' => 'Failed to get Redis status: ' . $e->getMessage()];
        }
        break;
        
    case 'flushall':
        try {
            if ($redis->flushAll()) {
                $response = ['success' => true, 'message' => 'All Redis databases flushed successfully'];
                
                // Log the action
                $log_entry = date('Y-m-d H:i:s') . " - Admin: " . $_SESSION['admin_username'] . " - Redis flushall\n";
                file_put_contents('/var/log/webserver-dashboard/cache-management.log', $log_entry, FILE_APPEND | LOCK_EX);
            } else {
                $response = ['success' => false, 'message' => 'Failed to flush all Redis databases'];
            }
        } catch (Exception $e) {
            $response = ['success' => false, 'message' => 'Error flushing Redis: ' . $e->getMessage()];
        }
        break;
        
    case 'flushdb':
        $db = intval($_POST['database'] ?? $_GET['database'] ?? 0);
        try {
            $redis->select($db);
            if ($redis->flushDB()) {
                $response = ['success' => true, 'message' => "Database $db flushed successfully"];
                
                // Log the action
                $log_entry = date('Y-m-d H:i:s') . " - Admin: " . $_SESSION['admin_username'] . " - Redis flushdb: $db\n";
                file_put_contents('/var/log/webserver-dashboard/cache-management.log', $log_entry, FILE_APPEND | LOCK_EX);
            } else {
                $response = ['success' => false, 'message' => "Failed to flush database $db"];
            }
        } catch (Exception $e) {
            $response = ['success' => false, 'message' => 'Error flushing database: ' . $e->getMessage()];
        }
        break;
        
    case 'get_keys':
        $db = intval($_POST['database'] ?? $_GET['database'] ?? 0);
        $pattern = $_POST['pattern'] ?? $_GET['pattern'] ?? '*';
        $limit = intval($_POST['limit'] ?? $_GET['limit'] ?? 100);
        
        try {
            $redis->select($db);
            $keys = $redis->keys($pattern);
            
            // Limit results
            if (count($keys) > $limit) {
                $keys = array_slice($keys, 0, $limit);
            }
            
            $key_data = [];
            foreach ($keys as $key) {
                $type = $redis->type($key);
                $ttl = $redis->ttl($key);
                $size = 0;
                
                // Get size based on type
                switch ($type) {
                    case Redis::REDIS_STRING:
                        $size = strlen($redis->get($key));
                        break;
                    case Redis::REDIS_LIST:
                        $size = $redis->lLen($key);
                        break;
                    case Redis::REDIS_SET:
                        $size = $redis->sCard($key);
                        break;
                    case Redis::REDIS_ZSET:
                        $size = $redis->zCard($key);
                        break;
                    case Redis::REDIS_HASH:
                        $size = $redis->hLen($key);
                        break;
                }
                
                $key_data[] = [
                    'key' => $key,
                    'type' => $type,
                    'ttl' => $ttl,
                    'size' => $size
                ];
            }
            
            $response = [
                'success' => true,
                'message' => 'Keys retrieved successfully',
                'data' => [
                    'database' => $db,
                    'pattern' => $pattern,
                    'total_found' => count($redis->keys($pattern)),
                    'returned' => count($key_data),
                    'keys' => $key_data
                ]
            ];
        } catch (Exception $e) {
            $response = ['success' => false, 'message' => 'Error retrieving keys: ' . $e->getMessage()];
        }
        break;
        
    case 'delete_key':
        $key = $_POST['key'] ?? $_GET['key'] ?? '';
        $db = intval($_POST['database'] ?? $_GET['database'] ?? 0);
        
        if (empty($key)) {
            $response = ['success' => false, 'message' => 'Key name is required'];
        } else {
            try {
                $redis->select($db);
                if ($redis->del($key)) {
                    $response = ['success' => true, 'message' => "Key '$key' deleted successfully"];
                    
                    // Log the action
                    $log_entry = date('Y-m-d H:i:s') . " - Admin: " . $_SESSION['admin_username'] . " - Redis delete key: $key (db: $db)\n";
                    file_put_contents('/var/log/webserver-dashboard/cache-management.log', $log_entry, FILE_APPEND | LOCK_EX);
                } else {
                    $response = ['success' => false, 'message' => "Key '$key' not found or failed to delete"];
                }
            } catch (Exception $e) {
                $response = ['success' => false, 'message' => 'Error deleting key: ' . $e->getMessage()];
            }
        }
        break;
        
    case 'set_key':
        $key = $_POST['key'] ?? '';
        $value = $_POST['value'] ?? '';
        $db = intval($_POST['database'] ?? 0);
        $ttl = intval($_POST['ttl'] ?? 0);
        
        if (empty($key)) {
            $response = ['success' => false, 'message' => 'Key name is required'];
        } else {
            try {
                $redis->select($db);
                
                if ($ttl > 0) {
                    $result = $redis->setex($key, $ttl, $value);
                } else {
                    $result = $redis->set($key, $value);
                }
                
                if ($result) {
                    $ttl_msg = $ttl > 0 ? " with TTL $ttl seconds" : "";
                    $response = ['success' => true, 'message' => "Key '$key' set successfully$ttl_msg"];
                    
                    // Log the action
                    $log_entry = date('Y-m-d H:i:s') . " - Admin: " . $_SESSION['admin_username'] . " - Redis set key: $key (db: $db)$ttl_msg\n";
                    file_put_contents('/var/log/webserver-dashboard/cache-management.log', $log_entry, FILE_APPEND | LOCK_EX);
                } else {
                    $response = ['success' => false, 'message' => "Failed to set key '$key'"];
                }
            } catch (Exception $e) {
                $response = ['success' => false, 'message' => 'Error setting key: ' . $e->getMessage()];
            }
        }
        break;
        
    case 'get_key':
        $key = $_POST['key'] ?? $_GET['key'] ?? '';
        $db = intval($_POST['database'] ?? $_GET['database'] ?? 0);
        
        if (empty($key)) {
            $response = ['success' => false, 'message' => 'Key name is required'];
        } else {
            try {
                $redis->select($db);
                $value = $redis->get($key);
                $type = $redis->type($key);
                $ttl = $redis->ttl($key);
                
                if ($value !== false) {
                    $response = [
                        'success' => true,
                        'message' => "Key '$key' retrieved successfully",
                        'data' => [
                            'key' => $key,
                            'value' => $value,
                            'type' => $type,
                            'ttl' => $ttl
                        ]
                    ];
                } else {
                    $response = ['success' => false, 'message' => "Key '$key' not found"];
                }
            } catch (Exception $e) {
                $response = ['success' => false, 'message' => 'Error retrieving key: ' . $e->getMessage()];
            }
        }
        break;
        
    case 'info':
        try {
            $info = $redis->info();
            $response = [
                'success' => true,
                'message' => 'Redis info retrieved',
                'data' => $info
            ];
        } catch (Exception $e) {
            $response = ['success' => false, 'message' => 'Error getting Redis info: ' . $e->getMessage()];
        }
        break;
        
    default:
        $response = ['success' => false, 'message' => 'Invalid action'];
        break;
}

// Close Redis connection
if ($redis) {
    $redis->close();
}

echo json_encode($response);
?>
