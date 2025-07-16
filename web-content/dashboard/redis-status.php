<?php
// Redis Status and Management Interface
session_start();

// Security check - only allow access from dashboard
$allowed_referers = ['dashboard.local', 'localhost', '127.0.0.1'];
$referer_host = isset($_SERVER['HTTP_REFERER']) ? parse_url($_SERVER['HTTP_REFERER'], PHP_URL_HOST) : '';

if (!in_array($referer_host, $allowed_referers) && !isset($_GET['direct'])) {
    http_response_code(403);
    die('Access denied');
}

// Redis connection
$redis = null;
$redis_available = false;

try {
    if (class_exists('Redis')) {
        $redis = new Redis();
        $redis->connect('127.0.0.1', 6379);
        $redis_available = true;
    }
} catch (Exception $e) {
    $redis_error = $e->getMessage();
}

// Handle Redis actions
if ($_POST && isset($_POST['action']) && $redis_available) {
    $response = ['success' => false, 'message' => ''];
    
    switch ($_POST['action']) {
        case 'flushall':
            try {
                if ($redis->flushAll()) {
                    $response = ['success' => true, 'message' => 'All Redis databases flushed successfully'];
                } else {
                    $response = ['success' => false, 'message' => 'Failed to flush Redis databases'];
                }
            } catch (Exception $e) {
                $response = ['success' => false, 'message' => 'Error: ' . $e->getMessage()];
            }
            break;
            
        case 'flushdb':
            $db = intval($_POST['database'] ?? 0);
            try {
                $redis->select($db);
                if ($redis->flushDB()) {
                    $response = ['success' => true, 'message' => "Database $db flushed successfully"];
                } else {
                    $response = ['success' => false, 'message' => "Failed to flush database $db"];
                }
            } catch (Exception $e) {
                $response = ['success' => false, 'message' => 'Error: ' . $e->getMessage()];
            }
            break;
            
        case 'delete_key':
            $key = $_POST['key'] ?? '';
            $db = intval($_POST['database'] ?? 0);
            if (!empty($key)) {
                try {
                    $redis->select($db);
                    if ($redis->del($key)) {
                        $response = ['success' => true, 'message' => "Key '$key' deleted successfully"];
                    } else {
                        $response = ['success' => false, 'message' => "Key '$key' not found or failed to delete"];
                    }
                } catch (Exception $e) {
                    $response = ['success' => false, 'message' => 'Error: ' . $e->getMessage()];
                }
            } else {
                $response = ['success' => false, 'message' => 'Key name is required'];
            }
            break;
            
        case 'set_key':
            $key = $_POST['key'] ?? '';
            $value = $_POST['value'] ?? '';
            $db = intval($_POST['database'] ?? 0);
            $ttl = intval($_POST['ttl'] ?? 0);
            
            if (!empty($key)) {
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
                    } else {
                        $response = ['success' => false, 'message' => "Failed to set key '$key'"];
                    }
                } catch (Exception $e) {
                    $response = ['success' => false, 'message' => 'Error: ' . $e->getMessage()];
                }
            } else {
                $response = ['success' => false, 'message' => 'Key name is required'];
            }
            break;
    }
    
    if (isset($_POST['ajax'])) {
        header('Content-Type: application/json');
        echo json_encode($response);
        exit;
    }
    
    $_SESSION['redis_message'] = $response;
    header('Location: ' . $_SERVER['PHP_SELF']);
    exit;
}

// Get Redis info
$redis_info = [];
$redis_stats = [];
$databases = [];

if ($redis_available) {
    try {
        $redis_info = $redis->info();
        
        // Get database information
        for ($i = 0; $i < 16; $i++) {
            $redis->select($i);
            $dbsize = $redis->dbSize();
            if ($dbsize > 0) {
                $databases[$i] = [
                    'size' => $dbsize,
                    'keys' => $redis->keys('*')
                ];
            }
        }
        
        // Parse stats
        if (isset($redis_info['keyspace_hits']) && isset($redis_info['keyspace_misses'])) {
            $hits = intval($redis_info['keyspace_hits']);
            $misses = intval($redis_info['keyspace_misses']);
            $total = $hits + $misses;
            $redis_stats['hit_rate'] = $total > 0 ? ($hits / $total) * 100 : 0;
            $redis_stats['hits'] = $hits;
            $redis_stats['misses'] = $misses;
        }
        
    } catch (Exception $e) {
        $redis_error = $e->getMessage();
    }
}

// Format bytes
function formatBytes($bytes, $precision = 2) {
    $units = array('B', 'KB', 'MB', 'GB', 'TB');
    
    for ($i = 0; $bytes > 1024; $i++) {
        $bytes /= 1024;
    }
    
    return round($bytes, $precision) . ' ' . $units[$i];
}

// Get message from session
$message = $_SESSION['redis_message'] ?? null;
unset($_SESSION['redis_message']);
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Redis Status - Web Server Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
        }
        
        .header h1 {
            color: #2d3748;
            font-size: 2.5rem;
            font-weight: 700;
            margin-bottom: 10px;
        }
        
        .header p {
            color: #718096;
            font-size: 1.1rem;
        }
        
        .back-link {
            display: inline-block;
            margin-top: 15px;
            padding: 10px 20px;
            background: #4299e1;
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            transition: background 0.2s;
        }
        
        .back-link:hover {
            background: #3182ce;
        }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 30px;
            margin-bottom: 30px;
        }
        
        .card {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
        }
        
        .card h2 {
            color: #2d3748;
            font-size: 1.5rem;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .status-indicator {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            display: inline-block;
        }
        
        .status-connected {
            background: #48bb78;
        }
        
        .status-disconnected {
            background: #f56565;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        
        .stat-item {
            text-align: center;
            padding: 15px;
            background: #f7fafc;
            border-radius: 12px;
        }
        
        .stat-number {
            font-size: 1.5rem;
            font-weight: 700;
            color: #4299e1;
        }
        
        .stat-label {
            color: #718096;
            font-size: 0.9rem;
            margin-top: 5px;
        }
        
        .progress-bar {
            width: 100%;
            height: 20px;
            background: #e2e8f0;
            border-radius: 10px;
            overflow: hidden;
            margin: 10px 0;
        }
        
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #48bb78, #38a169);
            transition: width 0.3s ease;
        }
        
        .progress-text {
            text-align: center;
            font-size: 0.9rem;
            color: #4a5568;
            margin-top: 5px;
        }
        
        .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            transition: all 0.2s ease;
            text-decoration: none;
            display: inline-block;
            font-size: 0.9rem;
            margin: 5px;
        }
        
        .btn-danger {
            background: #f56565;
            color: white;
        }
        
        .btn-danger:hover {
            background: #e53e3e;
        }
        
        .btn-primary {
            background: #4299e1;
            color: white;
        }
        
        .btn-primary:hover {
            background: #3182ce;
        }
        
        .btn-secondary {
            background: #e2e8f0;
            color: #4a5568;
        }
        
        .btn-secondary:hover {
            background: #cbd5e0;
        }
        
        .btn-small {
            padding: 4px 8px;
            font-size: 0.8rem;
        }
        
        .message {
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
            font-weight: 600;
        }
        
        .message.success {
            background: #c6f6d5;
            color: #22543d;
            border: 1px solid #9ae6b4;
        }
        
        .message.error {
            background: #fed7d7;
            color: #742a2a;
            border: 1px solid #feb2b2;
        }
        
        .info-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        
        .info-table th,
        .info-table td {
            padding: 8px 12px;
            text-align: left;
            border-bottom: 1px solid #e2e8f0;
        }
        
        .info-table th {
            background: #f7fafc;
            font-weight: 600;
            color: #2d3748;
        }
        
        .info-table td {
            color: #4a5568;
            font-family: monospace;
            font-size: 0.9rem;
        }
        
        .database-list {
            max-height: 300px;
            overflow-y: auto;
        }
        
        .database-item {
            background: #f7fafc;
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 15px;
        }
        
        .database-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
        }
        
        .database-title {
            font-weight: 600;
            color: #2d3748;
        }
        
        .key-list {
            max-height: 150px;
            overflow-y: auto;
            background: white;
            border-radius: 6px;
            padding: 10px;
        }
        
        .key-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 5px 0;
            border-bottom: 1px solid #e2e8f0;
            font-family: monospace;
            font-size: 0.85rem;
        }
        
        .key-item:last-child {
            border-bottom: none;
        }
        
        .key-name {
            color: #4a5568;
            flex: 1;
            margin-right: 10px;
            word-break: break-all;
        }
        
        .form-group {
            margin-bottom: 15px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: 600;
            color: #2d3748;
        }
        
        .form-group input,
        .form-group textarea,
        .form-group select {
            width: 100%;
            padding: 10px;
            border: 2px solid #e2e8f0;
            border-radius: 8px;
            font-size: 1rem;
        }
        
        .form-group input:focus,
        .form-group textarea:focus,
        .form-group select:focus {
            outline: none;
            border-color: #4299e1;
        }
        
        .form-row {
            display: flex;
            gap: 10px;
        }
        
        .form-row .form-group {
            flex: 1;
        }
        
        .disabled-notice {
            text-align: center;
            padding: 40px;
            color: #718096;
            font-style: italic;
        }
        
        .refresh-btn {
            position: fixed;
            bottom: 30px;
            right: 30px;
            width: 60px;
            height: 60px;
            border-radius: 50%;
            background: #4299e1;
            color: white;
            border: none;
            font-size: 1.2rem;
            cursor: pointer;
            box-shadow: 0 4px 12px rgba(66, 153, 225, 0.4);
            transition: all 0.2s ease;
        }
        
        .refresh-btn:hover {
            background: #3182ce;
            transform: scale(1.1);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔴 Redis Status & Management</h1>
            <p>Monitor and manage Redis cache server</p>
            <a href="/" class="back-link">← Back to Dashboard</a>
        </div>
        
        <?php if ($message): ?>
            <div class="message <?php echo $message['success'] ? 'success' : 'error'; ?>">
                <?php echo htmlspecialchars($message['message']); ?>
            </div>
        <?php endif; ?>
        
        <?php if (!$redis_available): ?>
            <div class="card">
                <div class="disabled-notice">
                    <h2>Redis is not available</h2>
                    <p>Redis extension is not installed or Redis server is not running.</p>
                    <?php if (isset($redis_error)): ?>
                        <p style="color: #e53e3e; margin-top: 10px;">Error: <?php echo htmlspecialchars($redis_error); ?></p>
                    <?php endif; ?>
                </div>
            </div>
        <?php else: ?>
            <div class="grid">
                <div class="card">
                    <h2>
                        <span class="status-indicator status-connected"></span>
                        Redis Status
                    </h2>
                    
                    <div class="stats-grid">
                        <div class="stat-item">
                            <div class="stat-number"><?php echo isset($redis_stats['hit_rate']) ? number_format($redis_stats['hit_rate'], 1) : '0'; ?>%</div>
                            <div class="stat-label">Hit Rate</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-number"><?php echo count($databases); ?></div>
                            <div class="stat-label">Active DBs</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-number"><?php echo isset($redis_stats['hits']) ? number_format($redis_stats['hits']) : '0'; ?></div>
                            <div class="stat-label">Cache Hits</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-number"><?php echo isset($redis_stats['misses']) ? number_format($redis_stats['misses']) : '0'; ?></div>
                            <div class="stat-label">Cache Misses</div>
                        </div>
                    </div>
                    
                    <?php if (isset($redis_stats['hit_rate'])): ?>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: <?php echo $redis_stats['hit_rate']; ?>%"></div>
                        </div>
                        <div class="progress-text">Cache Hit Rate: <?php echo number_format($redis_stats['hit_rate'], 2); ?>%</div>
                    <?php endif; ?>
                    
                    <div style="margin-top: 20px;">
                        <form method="post" style="display: inline;">
                            <input type="hidden" name="action" value="flushall">
                            <button type="submit" class="btn btn-danger" onclick="return confirm('Are you sure you want to flush ALL Redis databases? This will clear all cached data.')">
                                🗑️ Flush All Databases
                            </button>
                        </form>
                        <button onclick="location.reload()" class="btn btn-secondary">
                            ↻ Refresh Status
                        </button>
                    </div>
                </div>
                
                <div class="card">
                    <h2>📊 Server Information</h2>
                    
                    <table class="info-table">
                        <thead>
                            <tr>
                                <th>Property</th>
                                <th>Value</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr>
                                <td>Redis Version</td>
                                <td><?php echo htmlspecialchars($redis_info['redis_version'] ?? 'Unknown'); ?></td>
                            </tr>
                            <tr>
                                <td>Uptime</td>
                                <td><?php echo isset($redis_info['uptime_in_seconds']) ? gmdate('H:i:s', $redis_info['uptime_in_seconds']) : 'Unknown'; ?></td>
                            </tr>
                            <tr>
                                <td>Connected Clients</td>
                                <td><?php echo htmlspecialchars($redis_info['connected_clients'] ?? '0'); ?></td>
                            </tr>
                            <tr>
                                <td>Used Memory</td>
                                <td><?php echo isset($redis_info['used_memory']) ? formatBytes($redis_info['used_memory']) : 'Unknown'; ?></td>
                            </tr>
                            <tr>
                                <td>Max Memory</td>
                                <td><?php echo isset($redis_info['maxmemory']) && $redis_info['maxmemory'] > 0 ? formatBytes($redis_info['maxmemory']) : 'No limit'; ?></td>
                            </tr>
                            <tr>
                                <td>Memory Policy</td>
                                <td><?php echo htmlspecialchars($redis_info['maxmemory_policy'] ?? 'noeviction'); ?></td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
            
            <div class="grid">
                <div class="card">
                    <h2>🗄️ Database Management</h2>
                    
                    <?php if (empty($databases)): ?>
                        <p style="color: #718096; font-style: italic;">No databases contain data</p>
                    <?php else: ?>
                        <div class="database-list">
                            <?php foreach ($databases as $db_num => $db_info): ?>
                                <div class="database-item">
                                    <div class="database-header">
                                        <div class="database-title">Database <?php echo $db_num; ?> (<?php echo $db_info['size']; ?> keys)</div>
                                        <form method="post" style="display: inline;">
                                            <input type="hidden" name="action" value="flushdb">
                                            <input type="hidden" name="database" value="<?php echo $db_num; ?>">
                                            <button type="submit" class="btn btn-danger btn-small" onclick="return confirm('Are you sure you want to flush database <?php echo $db_num; ?>?')">
                                                Flush DB
                                            </button>
                                        </form>
                                    </div>
                                    
                                    <div class="key-list">
                                        <?php foreach (array_slice($db_info['keys'], 0, 10) as $key): ?>
                                            <div class="key-item">
                                                <div class="key-name"><?php echo htmlspecialchars($key); ?></div>
                                                <form method="post" style="display: inline;">
                                                    <input type="hidden" name="action" value="delete_key">
                                                    <input type="hidden" name="database" value="<?php echo $db_num; ?>">
                                                    <input type="hidden" name="key" value="<?php echo htmlspecialchars($key); ?>">
                                                    <button type="submit" class="btn btn-danger btn-small" onclick="return confirm('Delete key: <?php echo htmlspecialchars($key); ?>?')">
                                                        Delete
                                                    </button>
                                                </form>
                                            </div>
                                        <?php endforeach; ?>
                                        
                                        <?php if (count($db_info['keys']) > 10): ?>
                                            <div style="text-align: center; padding: 10px; color: #718096; font-style: italic;">
                                                ... and <?php echo count($db_info['keys']) - 10; ?> more keys
                                            </div>
                                        <?php endif; ?>
                                    </div>
                                </div>
                            <?php endforeach; ?>
                        </div>
                    <?php endif; ?>
                </div>
                
                <div class="card">
                    <h2>➕ Add/Update Key</h2>
                    
                    <form method="post">
                        <input type="hidden" name="action" value="set_key">
                        
                        <div class="form-row">
                            <div class="form-group">
                                <label for="database">Database:</label>
                                <select id="database" name="database">
                                    <?php for ($i = 0; $i < 16; $i++): ?>
                                        <option value="<?php echo $i; ?>">Database <?php echo $i; ?></option>
                                    <?php endfor; ?>
                                </select>
                            </div>
                            <div class="form-group">
                                <label for="ttl">TTL (seconds, 0 = no expiry):</label>
                                <input type="number" id="ttl" name="ttl" value="0" min="0">
                            </div>
                        </div>
                        
                        <div class="form-group">
                            <label for="key">Key Name:</label>
                            <input type="text" id="key" name="key" required placeholder="my_cache_key">
                        </div>
                        
                        <div class="form-group">
                            <label for="value">Value:</label>
                            <textarea id="value" name="value" rows="4" placeholder="Key value..."></textarea>
                        </div>
                        
                        <button type="submit" class="btn btn-primary">Set Key</button>
                    </form>
                </div>
            </div>
        <?php endif; ?>
    </div>
    
    <button class="refresh-btn" onclick="location.reload()" title="Refresh Status">
        ↻
    </button>
    
    <script>
        // Auto-refresh every 30 seconds
        setInterval(function() {
            location.reload();
        }, 30000);
    </script>
</body>
</html>
