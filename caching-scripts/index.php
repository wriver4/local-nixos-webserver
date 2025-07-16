<?php
session_start();

// Admin authentication configuration
$admin_config = [
    'username' => 'admin',
    'password' => password_hash('admin123', PASSWORD_DEFAULT), // Change this password!
    'session_timeout' => 3600 // 1 hour
];

// Check if user is logged in
function isLoggedIn() {
    return isset($_SESSION['cache_admin_logged_in']) && 
           $_SESSION['cache_admin_logged_in'] === true &&
           isset($_SESSION['cache_admin_login_time']) &&
           (time() - $_SESSION['cache_admin_login_time']) < $GLOBALS['admin_config']['session_timeout'];
}

// Handle login
if ($_POST && isset($_POST['action']) && $_POST['action'] === 'login') {
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';
    
    if ($username === $admin_config['username'] && password_verify($password, $admin_config['password'])) {
        $_SESSION['cache_admin_logged_in'] = true;
        $_SESSION['cache_admin_login_time'] = time();
        $_SESSION['cache_admin_username'] = $username;
        header('Location: ' . $_SERVER['PHP_SELF']);
        exit;
    } else {
        $login_error = 'Invalid username or password';
    }
}

// Handle logout
if ($_GET && isset($_GET['action']) && $_GET['action'] === 'logout') {
    session_destroy();
    header('Location: ' . $_SERVER['PHP_SELF']);
    exit;
}

// Require authentication for all other actions
if (!isLoggedIn()) {
    ?>
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Caching Scripts - Admin Login</title>
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
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 20px;
            }
            
            .login-container {
                background: rgba(255, 255, 255, 0.95);
                backdrop-filter: blur(10px);
                border-radius: 20px;
                padding: 40px;
                box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
                width: 100%;
                max-width: 400px;
            }
            
            .login-header {
                text-align: center;
                margin-bottom: 30px;
            }
            
            .login-header h1 {
                color: #2d3748;
                font-size: 2rem;
                margin-bottom: 10px;
            }
            
            .login-header p {
                color: #718096;
            }
            
            .form-group {
                margin-bottom: 20px;
            }
            
            .form-group label {
                display: block;
                margin-bottom: 5px;
                font-weight: 600;
                color: #2d3748;
            }
            
            .form-group input {
                width: 100%;
                padding: 12px;
                border: 2px solid #e2e8f0;
                border-radius: 8px;
                font-size: 1rem;
                transition: border-color 0.2s;
            }
            
            .form-group input:focus {
                outline: none;
                border-color: #4299e1;
            }
            
            .btn {
                width: 100%;
                padding: 12px;
                background: #4299e1;
                color: white;
                border: none;
                border-radius: 8px;
                font-size: 1rem;
                font-weight: 600;
                cursor: pointer;
                transition: background 0.2s;
            }
            
            .btn:hover {
                background: #3182ce;
            }
            
            .error {
                background: #fed7d7;
                color: #742a2a;
                padding: 10px;
                border-radius: 8px;
                margin-bottom: 20px;
                border: 1px solid #feb2b2;
            }
            
            .back-link {
                display: block;
                text-align: center;
                margin-top: 20px;
                color: #4299e1;
                text-decoration: none;
                font-weight: 600;
            }
            
            .back-link:hover {
                color: #3182ce;
            }
        </style>
    </head>
    <body>
        <div class="login-container">
            <div class="login-header">
                <h1>🔐 Admin Login</h1>
                <p>Standalone Caching Scripts</p>
            </div>
            
            <?php if (isset($login_error)): ?>
                <div class="error"><?php echo htmlspecialchars($login_error); ?></div>
            <?php endif; ?>
            
            <form method="post">
                <input type="hidden" name="action" value="login">
                
                <div class="form-group">
                    <label for="username">Username:</label>
                    <input type="text" id="username" name="username" required>
                </div>
                
                <div class="form-group">
                    <label for="password">Password:</label>
                    <input type="password" id="password" name="password" required>
                </div>
                
                <button type="submit" class="btn">Login</button>
            </form>
            
            <a href="http://dashboard.local" class="back-link">← Back to Dashboard</a>
        </div>
    </body>
    </html>
    <?php
    exit;
}

// Handle script execution
$output = '';
$error = '';

if ($_POST && isset($_POST['action']) && $_POST['action'] === 'execute_script') {
    $script = $_POST['script'] ?? '';
    $params = $_POST['params'] ?? '';
    
    // Validate script name for security
    $allowed_scripts = [
        'manage-opcache',
        'manage-redis',
        'manage-hosts',
        'monitor-hosts',
        'create-site-db',
        'create-site-dir',
        'rebuild-webserver'
    ];
    
    if (!in_array($script, $allowed_scripts)) {
        $error = 'Invalid script name';
    } else {
        // Execute the script safely
        $command = "/usr/local/bin/$script";
        if (!empty($params)) {
            $command .= " " . escapeshellarg($params);
        }
        
        // Additional parameter handling for specific scripts
        if ($script === 'create-site-dir' && isset($_POST['domain']) && isset($_POST['site_name'])) {
            $command = "/usr/local/bin/$script " . escapeshellarg($_POST['domain']) . " " . escapeshellarg($_POST['site_name']);
        } elseif ($script === 'manage-hosts' && isset($_POST['hosts_action']) && isset($_POST['domain'])) {
            $command = "/usr/local/bin/$script " . escapeshellarg($_POST['hosts_action']) . " " . escapeshellarg($_POST['domain']);
        } elseif ($script === 'manage-opcache' && isset($_POST['opcache_action'])) {
            $command = "/usr/local/bin/$script " . escapeshellarg($_POST['opcache_action']);
            if ($_POST['opcache_action'] === 'invalidate' && isset($_POST['file_path'])) {
                $command .= " " . escapeshellarg($_POST['file_path']);
            }
        } elseif ($script === 'manage-redis' && isset($_POST['redis_action'])) {
            $command = "/usr/local/bin/$script " . escapeshellarg($_POST['redis_action']);
            if ($_POST['redis_action'] === 'flushdb' && isset($_POST['database'])) {
                $command .= " " . escapeshellarg($_POST['database']);
            }
        }
        
        // Execute command and capture output
        $output = shell_exec($command . ' 2>&1');
        
        // Log the action
        $log_entry = date('Y-m-d H:i:s') . " - Admin: " . $_SESSION['cache_admin_username'] . " - Executed: $command\n";
        file_put_contents('/var/log/caching-scripts/activity.log', $log_entry, FILE_APPEND | LOCK_EX);
    }
}

// Get system status
function getSystemStatus() {
    $status = [];
    
    // OPcache status
    if (function_exists('opcache_get_status')) {
        $opcache_status = opcache_get_status();
        if ($opcache_status) {
            $stats = $opcache_status['opcache_statistics'];
            $hits = $stats['hits'];
            $misses = $stats['misses'];
            $total = $hits + $misses;
            $status['opcache'] = [
                'enabled' => true,
                'hit_rate' => $total > 0 ? ($hits / $total) * 100 : 0,
                'cached_scripts' => $stats['num_cached_scripts']
            ];
        } else {
            $status['opcache'] = ['enabled' => false];
        }
    } else {
        $status['opcache'] = ['enabled' => false];
    }
    
    // Redis status
    if (class_exists('Redis')) {
        try {
            $redis = new Redis();
            $redis->connect('127.0.0.1', 6379);
            $info = $redis->info();
            
            $hits = intval($info['keyspace_hits'] ?? 0);
            $misses = intval($info['keyspace_misses'] ?? 0);
            $total = $hits + $misses;
            
            $status['redis'] = [
                'available' => true,
                'connected' => true,
                'hit_rate' => $total > 0 ? ($hits / $total) * 100 : 0,
                'version' => $info['redis_version'] ?? 'Unknown'
            ];
        } catch (Exception $e) {
            $status['redis'] = ['available' => true, 'connected' => false, 'error' => $e->getMessage()];
        }
    } else {
        $status['redis'] = ['available' => false];
    }
    
    return $status;
}

$system_status = getSystemStatus();
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Standalone Caching Scripts - Admin Panel</title>
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
            max-width: 1400px;
            margin: 0 auto;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .header-content h1 {
            color: #2d3748;
            font-size: 2.5rem;
            font-weight: 700;
            margin-bottom: 10px;
        }
        
        .header-content p {
            color: #718096;
            font-size: 1.1rem;
        }
        
        .admin-info {
            text-align: right;
        }
        
        .admin-info .admin-badge {
            background: #48bb78;
            color: white;
            padding: 8px 16px;
            border-radius: 20px;
            font-weight: 600;
            margin-bottom: 10px;
            display: inline-block;
        }
        
        .logout-btn {
            background: #f56565;
            color: white;
            padding: 8px 16px;
            border-radius: 8px;
            text-decoration: none;
            font-weight: 600;
            transition: background 0.2s;
        }
        
        .logout-btn:hover {
            background: #e53e3e;
        }
        
        .back-link {
            background: #4299e1;
            color: white;
            padding: 8px 16px;
            border-radius: 8px;
            text-decoration: none;
            font-weight: 600;
            transition: background 0.2s;
            margin-right: 10px;
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
        }
        
        .status-enabled {
            background: #48bb78;
        }
        
        .status-disabled {
            background: #f56565;
        }
        
        .status-error {
            background: #ed8936;
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
        
        .script-section {
            margin-bottom: 30px;
        }
        
        .script-section h3 {
            color: #2d3748;
            margin-bottom: 15px;
            padding-bottom: 10px;
            border-bottom: 2px solid #e2e8f0;
        }
        
        .script-form {
            background: #f7fafc;
            padding: 20px;
            border-radius: 12px;
            margin-bottom: 15px;
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
        .form-group select {
            width: 100%;
            padding: 10px;
            border: 2px solid #e2e8f0;
            border-radius: 8px;
            font-size: 1rem;
        }
        
        .form-group input:focus,
        .form-group select:focus {
            outline: none;
            border-color: #4299e1;
        }
        
        .form-row {
            display: flex;
            gap: 15px;
        }
        
        .form-row .form-group {
            flex: 1;
        }
        
        .btn {
            padding: 10px 20px;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            transition: all 0.2s ease;
            font-size: 0.9rem;
        }
        
        .btn-primary {
            background: #4299e1;
            color: white;
        }
        
        .btn-primary:hover {
            background: #3182ce;
        }
        
        .btn-danger {
            background: #f56565;
            color: white;
        }
        
        .btn-danger:hover {
            background: #e53e3e;
        }
        
        .btn-success {
            background: #48bb78;
            color: white;
        }
        
        .btn-success:hover {
            background: #38a169;
        }
        
        .output-section {
            margin-top: 30px;
        }
        
        .output-box {
            background: #1a202c;
            color: #e2e8f0;
            padding: 20px;
            border-radius: 8px;
            font-family: 'Courier New', monospace;
            font-size: 0.9rem;
            white-space: pre-wrap;
            max-height: 400px;
            overflow-y: auto;
            border: 2px solid #2d3748;
        }
        
        .error-box {
            background: #fed7d7;
            color: #742a2a;
            padding: 15px;
            border-radius: 8px;
            border: 1px solid #feb2b2;
            margin-bottom: 20px;
        }
        
        .quick-actions {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        
        .quick-action {
            padding: 15px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 12px;
            cursor: pointer;
            font-weight: 600;
            transition: transform 0.2s ease;
        }
        
        .quick-action:hover {
            transform: scale(1.05);
        }
        
        .warning {
            background: #fefcbf;
            color: #744210;
            padding: 15px;
            border-radius: 8px;
            border: 1px solid #f6e05e;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="header-content">
                <h1>🛠️ Standalone Caching Scripts</h1>
                <p>Independent Cache Management System</p>
            </div>
            <div class="admin-info">
                <div class="admin-badge">👤 Admin: <?php echo htmlspecialchars($_SESSION['cache_admin_username']); ?></div>
                <div>
                    <a href="http://dashboard.local" class="back-link">← Dashboard</a>
                    <a href="?action=logout" class="logout-btn">Logout</a>
                </div>
            </div>
        </div>
        
        <div class="grid">
            <div class="card">
                <h2>
                    <span class="status-indicator <?php echo $system_status['opcache']['enabled'] ? 'status-enabled' : 'status-disabled'; ?>"></span>
                    ⚡ OPcache Status
                </h2>
                
                <?php if ($system_status['opcache']['enabled']): ?>
                    <div class="stats-grid">
                        <div class="stat-item">
                            <div class="stat-number"><?php echo number_format($system_status['opcache']['hit_rate'], 1); ?>%</div>
                            <div class="stat-label">Hit Rate</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-number"><?php echo number_format($system_status['opcache']['cached_scripts']); ?></div>
                            <div class="stat-label">Cached Scripts</div>
                        </div>
                    </div>
                <?php else: ?>
                    <p style="color: #718096; font-style: italic;">OPcache is not enabled</p>
                <?php endif; ?>
            </div>
            
            <div class="card">
                <h2>
                    <span class="status-indicator <?php echo $system_status['redis']['available'] && $system_status['redis']['connected'] ? 'status-enabled' : ($system_status['redis']['available'] ? 'status-error' : 'status-disabled'); ?>"></span>
                    🔴 Redis Status
                </h2>
                
                <?php if ($system_status['redis']['available'] && $system_status['redis']['connected']): ?>
                    <div class="stats-grid">
                        <div class="stat-item">
                            <div class="stat-number"><?php echo number_format($system_status['redis']['hit_rate'], 1); ?>%</div>
                            <div class="stat-label">Hit Rate</div>
                        </div>
                        <div class="stat-item">
                            <div class="stat-number"><?php echo $system_status['redis']['version']; ?></div>
                            <div class="stat-label">Version</div>
                        </div>
                    </div>
                <?php elseif (isset($system_status['redis']['error'])): ?>
                    <p style="color: #e53e3e; font-size: 0.9rem;"><?php echo htmlspecialchars($system_status['redis']['error']); ?></p>
                <?php else: ?>
                    <p style="color: #718096; font-style: italic;">Redis is not available</p>
                <?php endif; ?>
            </div>
        </div>
        
        <div class="warning">
            ⚠️ <strong>Warning:</strong> These are standalone caching scripts with system-level access. Use with caution and ensure you understand the impact of each command before execution.
        </div>
        
        <?php if (!empty($error)): ?>
            <div class="error-box">
                <strong>Error:</strong> <?php echo htmlspecialchars($error); ?>
            </div>
        <?php endif; ?>
        
        <div class="card">
            <h2>🚀 Quick Actions</h2>
            <div class="quick-actions">
                <form method="post" style="display: inline;">
                    <input type="hidden" name="action" value="execute_script">
                    <input type="hidden" name="script" value="manage-opcache">
                    <input type="hidden" name="opcache_action" value="status">
                    <button type="submit" class="quick-action">⚡ OPcache Status</button>
                </form>
                
                <form method="post" style="display: inline;">
                    <input type="hidden" name="action" value="execute_script">
                    <input type="hidden" name="script" value="manage-redis">
                    <input type="hidden" name="redis_action" value="status">
                    <button type="submit" class="quick-action">🔴 Redis Status</button>
                </form>
                
                <form method="post" style="display: inline;">
                    <input type="hidden" name="action" value="execute_script">
                    <input type="hidden" name="script" value="manage-hosts">
                    <input type="hidden" name="hosts_action" value="list">
                    <button type="submit" class="quick-action">🌐 List Hosts</button>
                </form>
                
                <form method="post" style="display: inline;">
                    <input type="hidden" name="action" value="execute_script">
                    <input type="hidden" name="script" value="monitor-hosts">
                    <button type="submit" class="quick-action">👁️ Monitor Hosts</button>
                </form>
            </div>
        </div>
        
        <div class="grid">
            <div class="card">
                <div class="script-section">
                    <h3>⚡ OPcache Management</h3>
                    
                    <div class="script-form">
                        <form method="post">
                            <input type="hidden" name="action" value="execute_script">
                            <input type="hidden" name="script" value="manage-opcache">
                            
                            <div class="form-group">
                                <label for="opcache_action">Action:</label>
                                <select id="opcache_action" name="opcache_action" onchange="toggleOPcacheFields(this.value)">
                                    <option value="status">Show Status</option>
                                    <option value="reset">Reset Cache</option>
                                    <option value="invalidate">Invalidate File</option>
                                </select>
                            </div>
                            
                            <div class="form-group" id="file_path_group" style="display: none;">
                                <label for="file_path">File Path:</label>
                                <input type="text" id="file_path" name="file_path" placeholder="/var/www/domain/file.php">
                            </div>
                            
                            <button type="submit" class="btn btn-primary">Execute</button>
                        </form>
                    </div>
                </div>
                
                <div class="script-section">
                    <h3>🔴 Redis Management</h3>
                    
                    <div class="script-form">
                        <form method="post">
                            <input type="hidden" name="action" value="execute_script">
                            <input type="hidden" name="script" value="manage-redis">
                            
                            <div class="form-row">
                                <div class="form-group">
                                    <label for="redis_action">Action:</label>
                                    <select id="redis_action" name="redis_action" onchange="toggleRedisFields(this.value)">
                                        <option value="status">Show Status</option>
                                        <option value="flushall">Flush All Databases</option>
                                        <option value="flushdb">Flush Specific Database</option>
                                        <option value="info">Show Info</option>
                                    </select>
                                </div>
                                
                                <div class="form-group" id="database_group" style="display: none;">
                                    <label for="database">Database:</label>
                                    <select id="database" name="database">
                                        <?php for ($i = 0; $i < 16; $i++): ?>
                                            <option value="<?php echo $i; ?>">Database <?php echo $i; ?></option>
                                        <?php endfor; ?>
                                    </select>
                                </div>
                            </div>
                            
                            <button type="submit" class="btn btn-primary">Execute</button>
                        </form>
                    </div>
                </div>
            </div>
            
            <div class="card">
                <div class="script-section">
                    <h3>🌐 Hosts File Management</h3>
                    
                    <div class="script-form">
                        <form method="post">
                            <input type="hidden" name="action" value="execute_script">
                            <input type="hidden" name="script" value="manage-hosts">
                            
                            <div class="form-row">
                                <div class="form-group">
                                    <label for="hosts_action">Action:</label>
                                    <select id="hosts_action" name="hosts_action" onchange="toggleHostsFields(this.value)">
                                        <option value="list">List Domains</option>
                                        <option value="add">Add Domain</option>
                                        <option value="remove">Remove Domain</option>
                                        <option value="backup">Create Backup</option>
                                    </select>
                                </div>
                                
                                <div class="form-group" id="domain_group" style="display: none;">
                                    <label for="domain">Domain:</label>
                                    <input type="text" id="domain" name="domain" placeholder="mysite.local">
                                </div>
                            </div>
                            
                            <button type="submit" class="btn btn-primary">Execute</button>
                        </form>
                    </div>
                </div>
                
                <div class="script-section">
                    <h3>🏗️ Site Management</h3>
                    
                    <div class="script-form">
                        <form method="post">
                            <input type="hidden" name="action" value="execute_script">
                            <input type="hidden" name="script" value="create-site-dir">
                            
                            <div class="form-row">
                                <div class="form-group">
                                    <label for="site_domain">Domain:</label>
                                    <input type="text" id="site_domain" name="domain" placeholder="newsite.local" required>
                                </div>
                                
                                <div class="form-group">
                                    <label for="site_name_input">Site Name:</label>
                                    <input type="text" id="site_name_input" name="site_name" placeholder="My New Site" required>
                                </div>
                            </div>
                            
                            <button type="submit" class="btn btn-success">Create Site Directory</button>
                        </form>
                    </div>
                    
                    <div class="script-form">
                        <form method="post">
                            <input type="hidden" name="action" value="execute_script">
                            <input type="hidden" name="script" value="create-site-db">
                            
                            <div class="form-group">
                                <label for="db_name">Database Name:</label>
                                <input type="text" id="db_name" name="params" placeholder="mysite_db" required>
                            </div>
                            
                            <button type="submit" class="btn btn-success">Create Database</button>
                        </form>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="card">
            <div class="script-section">
                <h3>🔄 System Management</h3>
                
                <div class="script-form">
                    <form method="post" onsubmit="return confirm('This will rebuild the NixOS configuration and restart services. Continue?')">
                        <input type="hidden" name="action" value="execute_script">
                        <input type="hidden" name="script" value="rebuild-webserver">
                        
                        <p style="margin-bottom: 15px; color: #718096;">
                            Rebuild NixOS configuration and restart web services. This may take several minutes.
                        </p>
                        
                        <button type="submit" class="btn btn-danger">🔄 Rebuild Web Server</button>
                    </form>
                </div>
            </div>
        </div>
        
        <?php if (!empty($output)): ?>
            <div class="output-section">
                <div class="card">
                    <h2>📋 Command Output</h2>
                    <div class="output-box"><?php echo htmlspecialchars($output); ?></div>
                </div>
            </div>
        <?php endif; ?>
    </div>
    
    <script>
        function toggleOPcacheFields(action) {
            const filePathGroup = document.getElementById('file_path_group');
            if (action === 'invalidate') {
                filePathGroup.style.display = 'block';
            } else {
                filePathGroup.style.display = 'none';
            }
        }
        
        function toggleRedisFields(action) {
            const databaseGroup = document.getElementById('database_group');
            if (action === 'flushdb') {
                databaseGroup.style.display = 'block';
            } else {
                databaseGroup.style.display = 'none';
            }
        }
        
        function toggleHostsFields(action) {
            const domainGroup = document.getElementById('domain_group');
            if (action === 'add' || action === 'remove') {
                domainGroup.style.display = 'block';
            } else {
                domainGroup.style.display = 'none';
            }
        }
        
        // Auto-refresh system status every 30 seconds
        setInterval(function() {
            // Only refresh if no forms are being filled
            const inputs = document.querySelectorAll('input, select');
            let hasActiveInput = false;
            inputs.forEach(input => {
                if (input === document.activeElement) {
                    hasActiveInput = true;
                }
            });
            
            if (!hasActiveInput) {
                location.reload();
            }
        }, 30000);
    </script>
</body>
</html>
