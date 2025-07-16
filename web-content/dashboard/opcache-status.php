<?php
// OPcache Status and Management Interface
session_start();

// Security check - only allow access from dashboard
$allowed_referers = ['dashboard.local', 'localhost', '127.0.0.1'];
$referer_host = isset($_SERVER['HTTP_REFERER']) ? parse_url($_SERVER['HTTP_REFERER'], PHP_URL_HOST) : '';

if (!in_array($referer_host, $allowed_referers) && !isset($_GET['direct'])) {
    http_response_code(403);
    die('Access denied');
}

// Handle OPcache actions
if ($_POST && isset($_POST['action'])) {
    $response = ['success' => false, 'message' => ''];
    
    switch ($_POST['action']) {
        case 'reset':
            if (function_exists('opcache_reset')) {
                if (opcache_reset()) {
                    $response = ['success' => true, 'message' => 'OPcache reset successfully'];
                } else {
                    $response = ['success' => false, 'message' => 'Failed to reset OPcache'];
                }
            } else {
                $response = ['success' => false, 'message' => 'OPcache not available'];
            }
            break;
            
        case 'invalidate':
            $file = $_POST['file'] ?? '';
            if (!empty($file) && function_exists('opcache_invalidate')) {
                if (opcache_invalidate($file, true)) {
                    $response = ['success' => true, 'message' => "File invalidated: $file"];
                } else {
                    $response = ['success' => false, 'message' => "Failed to invalidate: $file"];
                }
            } else {
                $response = ['success' => false, 'message' => 'Invalid file or OPcache not available'];
            }
            break;
            
        case 'compile':
            $file = $_POST['file'] ?? '';
            if (!empty($file) && function_exists('opcache_compile_file')) {
                if (file_exists($file) && opcache_compile_file($file)) {
                    $response = ['success' => true, 'message' => "File compiled: $file"];
                } else {
                    $response = ['success' => false, 'message' => "Failed to compile: $file"];
                }
            } else {
                $response = ['success' => false, 'message' => 'Invalid file or OPcache not available'];
            }
            break;
    }
    
    if (isset($_POST['ajax'])) {
        header('Content-Type: application/json');
        echo json_encode($response);
        exit;
    }
    
    $_SESSION['opcache_message'] = $response;
    header('Location: ' . $_SERVER['PHP_SELF']);
    exit;
}

// Get OPcache status
$opcache_enabled = function_exists('opcache_get_status');
$opcache_status = $opcache_enabled ? opcache_get_status() : null;
$opcache_config = $opcache_enabled ? opcache_get_configuration() : null;

// Format bytes
function formatBytes($bytes, $precision = 2) {
    $units = array('B', 'KB', 'MB', 'GB', 'TB');
    
    for ($i = 0; $bytes > 1024; $i++) {
        $bytes /= 1024;
    }
    
    return round($bytes, $precision) . ' ' . $units[$i];
}

// Calculate hit rate
$hit_rate = 0;
if ($opcache_status && isset($opcache_status['opcache_statistics'])) {
    $stats = $opcache_status['opcache_statistics'];
    $hits = $stats['hits'];
    $misses = $stats['misses'];
    $total = $hits + $misses;
    $hit_rate = $total > 0 ? ($hits / $total) * 100 : 0;
}

// Get message from session
$message = $_SESSION['opcache_message'] ?? null;
unset($_SESSION['opcache_message']);
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OPcache Status - Web Server Dashboard</title>
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
        
        .status-enabled {
            background: #48bb78;
        }
        
        .status-disabled {
            background: #f56565;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
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
        
        .config-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        
        .config-table th,
        .config-table td {
            padding: 8px 12px;
            text-align: left;
            border-bottom: 1px solid #e2e8f0;
        }
        
        .config-table th {
            background: #f7fafc;
            font-weight: 600;
            color: #2d3748;
        }
        
        .config-table td {
            color: #4a5568;
            font-family: monospace;
            font-size: 0.9rem;
        }
        
        .file-list {
            max-height: 300px;
            overflow-y: auto;
            background: #f7fafc;
            border-radius: 8px;
            padding: 15px;
        }
        
        .file-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 8px 0;
            border-bottom: 1px solid #e2e8f0;
            font-family: monospace;
            font-size: 0.85rem;
        }
        
        .file-item:last-child {
            border-bottom: none;
        }
        
        .file-path {
            color: #4a5568;
            flex: 1;
            margin-right: 10px;
            word-break: break-all;
        }
        
        .file-actions {
            display: flex;
            gap: 5px;
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
        
        .form-group input {
            width: 100%;
            padding: 10px;
            border: 2px solid #e2e8f0;
            border-radius: 8px;
            font-size: 1rem;
        }
        
        .form-group input:focus {
            outline: none;
            border-color: #4299e1;
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
            <h1>⚡ OPcache Status & Management</h1>
            <p>Monitor and manage PHP OPcache performance</p>
            <a href="/" class="back-link">← Back to Dashboard</a>
        </div>
        
        <?php if ($message): ?>
            <div class="message <?php echo $message['success'] ? 'success' : 'error'; ?>">
                <?php echo htmlspecialchars($message['message']); ?>
            </div>
        <?php endif; ?>
        
        <?php if (!$opcache_enabled): ?>
            <div class="card">
                <div class="disabled-notice">
                    <h2>OPcache is not enabled</h2>
                    <p>Please enable OPcache in your PHP configuration to use this interface.</p>
                </div>
            </div>
        <?php else: ?>
            <div class="grid">
                <div class="card">
                    <h2>
                        <span class="status-indicator <?php echo $opcache_status ? 'status-enabled' : 'status-disabled'; ?>"></span>
                        OPcache Status
                    </h2>
                    
                    <?php if ($opcache_status): ?>
                        <div class="stats-grid">
                            <div class="stat-item">
                                <div class="stat-number"><?php echo number_format($hit_rate, 1); ?>%</div>
                                <div class="stat-label">Hit Rate</div>
                            </div>
                            <div class="stat-item">
                                <div class="stat-number"><?php echo number_format($opcache_status['opcache_statistics']['num_cached_scripts']); ?></div>
                                <div class="stat-label">Cached Scripts</div>
                            </div>
                            <div class="stat-item">
                                <div class="stat-number"><?php echo number_format($opcache_status['opcache_statistics']['hits']); ?></div>
                                <div class="stat-label">Cache Hits</div>
                            </div>
                            <div class="stat-item">
                                <div class="stat-number"><?php echo number_format($opcache_status['opcache_statistics']['misses']); ?></div>
                                <div class="stat-label">Cache Misses</div>
                            </div>
                        </div>
                        
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: <?php echo $hit_rate; ?>%"></div>
                        </div>
                        <div class="progress-text">Cache Hit Rate: <?php echo number_format($hit_rate, 2); ?>%</div>
                    <?php endif; ?>
                    
                    <div style="margin-top: 20px;">
                        <form method="post" style="display: inline;">
                            <input type="hidden" name="action" value="reset">
                            <button type="submit" class="btn btn-danger" onclick="return confirm('Are you sure you want to reset OPcache? This will clear all cached files.')">
                                🔄 Reset OPcache
                            </button>
                        </form>
                        <button onclick="location.reload()" class="btn btn-secondary">
                            ↻ Refresh Status
                        </button>
                    </div>
                </div>
                
                <div class="card">
                    <h2>📊 Memory Usage</h2>
                    
                    <?php if ($opcache_status && isset($opcache_status['memory_usage'])): ?>
                        <?php 
                        $memory = $opcache_status['memory_usage'];
                        $used_memory = $memory['used_memory'];
                        $free_memory = $memory['free_memory'];
                        $wasted_memory = $memory['wasted_memory'];
                        $total_memory = $used_memory + $free_memory + $wasted_memory;
                        $used_percentage = ($used_memory / $total_memory) * 100;
                        $wasted_percentage = ($wasted_memory / $total_memory) * 100;
                        ?>
                        
                        <div class="stats-grid">
                            <div class="stat-item">
                                <div class="stat-number"><?php echo formatBytes($used_memory); ?></div>
                                <div class="stat-label">Used Memory</div>
                            </div>
                            <div class="stat-item">
                                <div class="stat-number"><?php echo formatBytes($free_memory); ?></div>
                                <div class="stat-label">Free Memory</div>
                            </div>
                            <div class="stat-item">
                                <div class="stat-number"><?php echo formatBytes($wasted_memory); ?></div>
                                <div class="stat-label">Wasted Memory</div>
                            </div>
                            <div class="stat-item">
                                <div class="stat-number"><?php echo formatBytes($total_memory); ?></div>
                                <div class="stat-label">Total Memory</div>
                            </div>
                        </div>
                        
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: <?php echo $used_percentage; ?>%"></div>
                        </div>
                        <div class="progress-text">Memory Usage: <?php echo number_format($used_percentage, 1); ?>%</div>
                        
                        <?php if ($wasted_percentage > 5): ?>
                            <div style="margin-top: 10px; padding: 10px; background: #fefcbf; border: 1px solid #f6e05e; border-radius: 6px; color: #744210;">
                                ⚠️ High memory waste detected (<?php echo number_format($wasted_percentage, 1); ?>%). Consider resetting OPcache.
                            </div>
                        <?php endif; ?>
                    <?php endif; ?>
                </div>
            </div>
            
            <div class="grid">
                <div class="card">
                    <h2>⚙️ Configuration</h2>
                    
                    <?php if ($opcache_config): ?>
                        <table class="config-table">
                            <thead>
                                <tr>
                                    <th>Setting</th>
                                    <th>Value</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($opcache_config['directives'] as $key => $value): ?>
                                    <?php if (strpos($key, 'opcache.') === 0): ?>
                                        <tr>
                                            <td><?php echo htmlspecialchars($key); ?></td>
                                            <td><?php echo is_bool($value) ? ($value ? 'On' : 'Off') : htmlspecialchars($value); ?></td>
                                        </tr>
                                    <?php endif; ?>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    <?php endif; ?>
                </div>
                
                <div class="card">
                    <h2>🔧 File Management</h2>
                    
                    <div class="form-group">
                        <label for="invalidate-file">Invalidate Specific File:</label>
                        <form method="post" style="display: flex; gap: 10px;">
                            <input type="hidden" name="action" value="invalidate">
                            <input type="text" id="invalidate-file" name="file" placeholder="/path/to/file.php" style="flex: 1;">
                            <button type="submit" class="btn btn-primary">Invalidate</button>
                        </form>
                    </div>
                    
                    <div class="form-group">
                        <label for="compile-file">Compile Specific File:</label>
                        <form method="post" style="display: flex; gap: 10px;">
                            <input type="hidden" name="action" value="compile">
                            <input type="text" id="compile-file" name="file" placeholder="/path/to/file.php" style="flex: 1;">
                            <button type="submit" class="btn btn-primary">Compile</button>
                        </form>
                    </div>
                </div>
            </div>
            
            <?php if ($opcache_status && isset($opcache_status['scripts'])): ?>
                <div class="card">
                    <h2>📁 Cached Files (<?php echo count($opcache_status['scripts']); ?> files)</h2>
                    
                    <div class="file-list">
                        <?php foreach ($opcache_status['scripts'] as $file => $info): ?>
                            <div class="file-item">
                                <div class="file-path"><?php echo htmlspecialchars($file); ?></div>
                                <div class="file-actions">
                                    <form method="post" style="display: inline;">
                                        <input type="hidden" name="action" value="invalidate">
                                        <input type="hidden" name="file" value="<?php echo htmlspecialchars($file); ?>">
                                        <input type="hidden" name="ajax" value="1">
                                        <button type="submit" class="btn btn-secondary" style="padding: 4px 8px; font-size: 0.8rem;">
                                            Invalidate
                                        </button>
                                    </form>
                                </div>
                            </div>
                        <?php endforeach; ?>
                    </div>
                </div>
            <?php endif; ?>
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
        
        // Handle AJAX form submissions
        document.addEventListener('DOMContentLoaded', function() {
            const forms = document.querySelectorAll('form[method="post"]');
            forms.forEach(form => {
                if (form.querySelector('input[name="ajax"]')) {
                    form.addEventListener('submit', function(e) {
                        e.preventDefault();
                        
                        const formData = new FormData(form);
                        fetch(window.location.href, {
                            method: 'POST',
                            body: formData
                        })
                        .then(response => response.json())
                        .then(data => {
                            if (data.success) {
                                // Show success message and refresh
                                alert(data.message);
                                location.reload();
                            } else {
                                alert('Error: ' + data.message);
                            }
                        })
                        .catch(error => {
                            alert('Error: ' + error.message);
                        });
                    });
                }
            });
        });
    </script>
</body>
</html>
