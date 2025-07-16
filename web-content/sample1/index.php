<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sample Site 1 - Portfolio</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
        }
        
        .hero {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 100px 0;
            text-align: center;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 20px;
        }
        
        .hero h1 {
            font-size: 3.5rem;
            margin-bottom: 20px;
            font-weight: 700;
        }
        
        .hero p {
            font-size: 1.3rem;
            margin-bottom: 30px;
            opacity: 0.9;
        }
        
        .btn {
            display: inline-block;
            padding: 15px 30px;
            background: rgba(255, 255, 255, 0.2);
            color: white;
            text-decoration: none;
            border-radius: 50px;
            font-weight: 600;
            transition: all 0.3s ease;
            backdrop-filter: blur(10px);
        }
        
        .btn:hover {
            background: rgba(255, 255, 255, 0.3);
            transform: translateY(-2px);
        }
        
        .section {
            padding: 80px 0;
        }
        
        .section h2 {
            text-align: center;
            font-size: 2.5rem;
            margin-bottom: 50px;
            color: #2d3748;
        }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
            margin-top: 40px;
        }
        
        .card {
            background: white;
            border-radius: 15px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
        }
        
        .card h3 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.5rem;
        }
        
        .card p {
            color: #666;
            margin-bottom: 20px;
        }
        
        .tech-stack {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-top: 15px;
        }
        
        .tech-tag {
            background: #f7fafc;
            color: #4a5568;
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 0.85rem;
            font-weight: 500;
        }
        
        .php-info {
            background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
            margin: 40px 0;
            text-align: center;
        }
        
        .php-features {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }
        
        .feature {
            background: rgba(255, 255, 255, 0.1);
            padding: 20px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        
        .feature h4 {
            margin-bottom: 10px;
            font-size: 1.1rem;
        }
        
        .feature p {
            font-size: 0.9rem;
            opacity: 0.9;
        }
        
        .nixos-info {
            background: linear-gradient(135deg, #4c51bf 0%, #667eea 100%);
            color: white;
            padding: 30px;
            border-radius: 15px;
            margin: 40px 0;
            text-align: center;
        }
        
        .nixos-features {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 25px;
            margin-top: 30px;
        }
        
        .nixos-feature {
            background: rgba(255, 255, 255, 0.1);
            padding: 25px;
            border-radius: 12px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        .nixos-feature h4 {
            margin-bottom: 12px;
            font-size: 1.2rem;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .nixos-feature p {
            font-size: 0.95rem;
            opacity: 0.9;
            line-height: 1.5;
        }
        
        footer {
            background: #2d3748;
            color: white;
            text-align: center;
            padding: 40px 0;
        }
        
        @media (max-width: 768px) {
            .hero h1 {
                font-size: 2.5rem;
            }
            
            .hero p {
                font-size: 1.1rem;
            }
            
            .section h2 {
                font-size: 2rem;
            }
            
            .nixos-features {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="hero">
        <div class="container">
            <h1>Creative Portfolio</h1>
            <p>Showcasing innovative web solutions with cutting-edge technology</p>
            <a href="#projects" class="btn">View My Work</a>
        </div>
    </div>

    <div class="php-info">
        <div class="container">
            <h2>🚀 Powered by PHP <?php echo PHP_VERSION; ?></h2>
            <p>This portfolio is built with the latest PHP technology and modern web standards</p>
            
            <?php if (version_compare(PHP_VERSION, '8.4.0', '>=')): ?>
            <div class="php-features">
                <div class="feature">
                    <h4>⚡ Property Hooks</h4>
                    <p>Cleaner object-oriented code with automatic getters and setters</p>
                </div>
                <div class="feature">
                    <h4>🔒 Asymmetric Visibility</h4>
                    <p>Enhanced access control with public readonly and private(set) modifiers</p>
                </div>
                <div class="feature">
                    <h4>🎯 Performance Boost</h4>
                    <p>JIT improvements and optimized memory management</p>
                </div>
                <div class="feature">
                    <h4>🛠️ New Functions</h4>
                    <p>Enhanced array and string manipulation capabilities</p>
                </div>
            </div>
            <?php endif; ?>
        </div>
    </div>

    <div class="nixos-info">
        <div class="container">
            <h2>🐧 Hosted on NixOS</h2>
            <p>Deployed on the most advanced Linux distribution with declarative configuration management</p>
            
            <div class="nixos-features">
                <div class="nixos-feature">
                    <h4>📦 Declarative Configuration</h4>
                    <p>Entire system configuration defined in code, ensuring reproducibility and version control</p>
                </div>
                <div class="nixos-feature">
                    <h4>🔄 Atomic Upgrades</h4>
                    <p>System updates are atomic and rollback-safe, eliminating broken system states</p>
                </div>
                <div class="nixos-feature">
                    <h4>🏗️ Reproducible Builds</h4>
                    <p>Identical system configurations across development, staging, and production environments</p>
                </div>
                <div class="nixos-feature">
                    <h4>🔧 Flake Support</h4>
                    <p>Modern dependency management with flakes for hermetic and reproducible configurations</p>
                </div>
                <div class="nixos-feature">
                    <h4>🌐 Web Server Stack</h4>
                    <p>Nginx + PHP-FPM <?php echo substr(PHP_VERSION, 0, 3); ?> + MariaDB configured declaratively</p>
                </div>
                <div class="nixos-feature">
                    <h4>🛡️ Security First</h4>
                    <p>Minimal attack surface with only required services and automatic security updates</p>
                </div>
            </div>
        </div>
    </div>

    <section class="section" id="projects">
        <div class="container">
            <h2>Featured Projects</h2>
            <div class="grid">
                <div class="card">
                    <h3>E-Commerce Platform</h3>
                    <p>A full-featured online store with modern UI/UX, secure payment processing, and advanced inventory management.</p>
                    <div class="tech-stack">
                        <span class="tech-tag">PHP <?php echo substr(PHP_VERSION, 0, 3); ?></span>
                        <span class="tech-tag">MySQL</span>
                        <span class="tech-tag">JavaScript</span>
                        <span class="tech-tag">NixOS</span>
                    </div>
                </div>
                
                <div class="card">
                    <h3>Content Management System</h3>
                    <p>Custom CMS built for scalability and ease of use, featuring drag-and-drop page builder and SEO optimization.</p>
                    <div class="tech-stack">
                        <span class="tech-tag">PHP <?php echo substr(PHP_VERSION, 0, 3); ?></span>
                        <span class="tech-tag">MariaDB</span>
                        <span class="tech-tag">Vue.js</span>
                        <span class="tech-tag">Nginx</span>
                    </div>
                </div>
                
                <div class="card">
                    <h3>Real-Time Analytics Dashboard</h3>
                    <p>Interactive dashboard for monitoring business metrics with real-time data visualization and reporting.</p>
                    <div class="tech-stack">
                        <span class="tech-tag">PHP <?php echo substr(PHP_VERSION, 0, 3); ?></span>
                        <span class="tech-tag">WebSockets</span>
                        <span class="tech-tag">Chart.js</span>
                        <span class="tech-tag">Redis</span>
                    </div>
                </div>
                
                <div class="card">
                    <h3>NixOS Infrastructure</h3>
                    <p>Declarative infrastructure management with NixOS, featuring automated deployments and configuration management.</p>
                    <div class="tech-stack">
                        <span class="tech-tag">NixOS</span>
                        <span class="tech-tag">Flakes</span>
                        <span class="tech-tag">Docker</span>
                        <span class="tech-tag">CI/CD</span>
                    </div>
                </div>
                
                <div class="card">
                    <h3>Mobile-First Web App</h3>
                    <p>Progressive web application with offline capabilities, push notifications, and responsive design.</p>
                    <div class="tech-stack">
                        <span class="tech-tag">PHP <?php echo substr(PHP_VERSION, 0, 3); ?></span>
                        <span class="tech-tag">PWA</span>
                        <span class="tech-tag">Service Workers</span>
                        <span class="tech-tag">IndexedDB</span>
                    </div>
                </div>
                
                <div class="card">
                    <h3>Microservices Architecture</h3>
                    <p>Scalable microservices platform with API gateway, service discovery, and distributed monitoring.</p>
                    <div class="tech-stack">
                        <span class="tech-tag">PHP <?php echo substr(PHP_VERSION, 0, 3); ?></span>
                        <span class="tech-tag">Docker</span>
                        <span class="tech-tag">Kubernetes</span>
                        <span class="tech-tag">NixOS</span>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <section class="section" style="background: #f8f9fa;">
        <div class="container">
            <h2>Technical Expertise</h2>
            <div class="grid">
                <div class="card">
                    <h3>🚀 Backend Development</h3>
                    <p>Expert in PHP <?php echo substr(PHP_VERSION, 0, 3); ?>, modern frameworks, database design, and server architecture with NixOS deployment.</p>
                </div>
                
                <div class="card">
                    <h3>🐧 NixOS Administration</h3>
                    <p>Advanced NixOS configuration management, flakes, declarative deployments, and reproducible infrastructure.</p>
                </div>
                
                <div class="card">
                    <h3>☁️ Cloud & DevOps</h3>
                    <p>Experience with cloud platforms, containerization, CI/CD pipelines, and infrastructure automation using NixOS.</p>
                </div>
                
                <div class="card">
                    <h3>🔒 Security & Performance</h3>
                    <p>Focus on web security best practices, performance optimization, and scalable architecture with NixOS security features.</p>
                </div>
            </div>
        </div>
    </section>

    <footer>
        <div class="container">
            <p>&copy; <?php echo date('Y'); ?> Creative Portfolio. Built with PHP <?php echo PHP_VERSION; ?> on NixOS.</p>
            <p>Server Time: <?php echo date('Y-m-d H:i:s T'); ?> | Declarative Configuration Management</p>
        </div>
    </footer>
</body>
</html>
