<?php
// Sample Site 3 - Portfolio/Agency Site
$db_config = [
    'host' => 'localhost',
    'username' => 'webuser',
    'password' => 'webpass123',
    'database' => 'sample3_db'
];

try {
    $pdo = new PDO("mysql:host={$db_config['host']};dbname={$db_config['database']}", 
                   $db_config['username'], $db_config['password']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Create projects table
    $pdo->exec("CREATE TABLE IF NOT EXISTS projects (
        id INT AUTO_INCREMENT PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        description TEXT NOT NULL,
        technologies VARCHAR(255),
        image_url VARCHAR(500),
        project_url VARCHAR(255),
        category VARCHAR(50),
        completed_at DATE,
        featured BOOLEAN DEFAULT FALSE
    )");
    
    // Create team table
    $pdo->exec("CREATE TABLE IF NOT EXISTS team_members (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        position VARCHAR(100),
        bio TEXT,
        image_url VARCHAR(500),
        linkedin_url VARCHAR(255),
        github_url VARCHAR(255)
    )");
    
    // Insert sample projects
    $count = $pdo->query("SELECT COUNT(*) FROM projects")->fetchColumn();
    if ($count == 0) {
        $pdo->exec("INSERT INTO projects (title, description, technologies, image_url, project_url, category, completed_at, featured) VALUES 
            ('E-Commerce Platform', 'A full-stack e-commerce solution with real-time inventory management, payment processing, and advanced analytics dashboard.', 'React, Node.js, PostgreSQL, Stripe', 'https://images.pexels.com/photos/230544/pexels-photo-230544.jpeg', '#', 'Web Development', '2024-01-15', TRUE),
            ('Mobile Banking App', 'Secure mobile banking application with biometric authentication, real-time transactions, and comprehensive financial management tools.', 'React Native, Firebase, Node.js', 'https://images.pexels.com/photos/4386431/pexels-photo-4386431.jpeg', '#', 'Mobile Development', '2023-12-20', TRUE),
            ('AI-Powered Analytics Dashboard', 'Machine learning dashboard that provides predictive analytics and automated insights for business intelligence.', 'Python, TensorFlow, React, D3.js', 'https://images.pexels.com/photos/590020/pexels-photo-590020.jpeg', '#', 'Data Science', '2024-02-10', FALSE),
            ('Cloud Infrastructure Migration', 'Complete migration of legacy systems to cloud infrastructure with improved scalability and reduced operational costs.', 'AWS, Docker, Kubernetes, Terraform', 'https://images.pexels.com/photos/1181675/pexels-photo-1181675.jpeg', '#', 'DevOps', '2023-11-30', FALSE),
            ('Healthcare Management System', 'Comprehensive healthcare management platform with patient records, appointment scheduling, and telemedicine capabilities.', 'Vue.js, Laravel, MySQL, WebRTC', 'https://images.pexels.com/photos/4386467/pexels-photo-4386467.jpeg', '#', 'Healthcare', '2024-01-05', TRUE),
            ('Real Estate Platform', 'Modern real estate platform with virtual tours, advanced search filters, and integrated mortgage calculator.', 'Next.js, Prisma, PostgreSQL, Mapbox', 'https://images.pexels.com/photos/280229/pexels-photo-280229.jpeg', '#', 'Web Development', '2023-10-15', FALSE)");
    }
    
    // Insert team members
    $team_count = $pdo->query("SELECT COUNT(*) FROM team_members")->fetchColumn();
    if ($team_count == 0) {
        $pdo->exec("INSERT INTO team_members (name, position, bio, image_url, linkedin_url, github_url) VALUES 
            ('Alex Thompson', 'Lead Developer', 'Full-stack developer with 8+ years of experience in modern web technologies and cloud architecture.', 'https://images.pexels.com/photos/2379004/pexels-photo-2379004.jpeg', '#', '#'),
            ('Sarah Kim', 'UI/UX Designer', 'Creative designer passionate about creating intuitive user experiences and beautiful interfaces.', 'https://images.pexels.com/photos/3756679/pexels-photo-3756679.jpeg', '#', '#'),
            ('Marcus Johnson', 'DevOps Engineer', 'Infrastructure specialist focused on scalable cloud solutions and automated deployment pipelines.', 'https://images.pexels.com/photos/2182970/pexels-photo-2182970.jpeg', '#', '#'),
            ('Emily Chen', 'Project Manager', 'Experienced project manager ensuring smooth delivery and client satisfaction across all projects.', 'https://images.pexels.com/photos/3756681/pexels-photo-3756681.jpeg', '#', '#')");
    }
    
    $projects = $pdo->query("SELECT * FROM projects ORDER BY featured DESC, completed_at DESC")->fetchAll(PDO::FETCH_ASSOC);
    $team = $pdo->query("SELECT * FROM team_members ORDER BY id")->fetchAll(PDO::FETCH_ASSOC);
} catch(PDOException $e) {
    $db_error = "Connection failed: " . $e->getMessage();
    $projects = [];
    $team = [];
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PixelCraft - Digital Agency</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #1a202c;
            overflow-x: hidden;
        }
        
        .hero {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            position: relative;
            overflow: hidden;
        }
        
        .hero::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: url('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><pattern id="grain" width="100" height="100" patternUnits="userSpaceOnUse"><circle cx="50" cy="50" r="1" fill="white" opacity="0.1"/></pattern></defs><rect width="100" height="100" fill="url(%23grain)"/></svg>');
            opacity: 0.3;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 20px;
            position: relative;
            z-index: 1;
        }
        
        .hero-content {
            text-align: center;
            max-width: 800px;
            margin: 0 auto;
        }
        
        .hero h1 {
            font-size: 4rem;
            font-weight: 700;
            margin-bottom: 1rem;
            background: linear-gradient(45deg, #fff, #e2e8f0);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
        }
        
        .hero p {
            font-size: 1.3rem;
            margin-bottom: 2rem;
            opacity: 0.9;
        }
        
        .cta-button {
            display: inline-block;
            background: rgba(255, 255, 255, 0.2);
            color: white;
            padding: 1rem 2rem;
            border-radius: 50px;
            text-decoration: none;
            font-weight: 600;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.3);
            transition: all 0.3s ease;
        }
        
        .cta-button:hover {
            background: rgba(255, 255, 255, 0.3);
            transform: translateY(-2px);
        }
        
        .nav {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            z-index: 1000;
            padding: 1rem 0;
            transition: all 0.3s ease;
        }
        
        .nav ul {
            list-style: none;
            display: flex;
            justify-content: center;
            gap: 2rem;
        }
        
        .nav a {
            text-decoration: none;
            color: #1a202c;
            font-weight: 600;
            padding: 0.5rem 1rem;
            border-radius: 25px;
            transition: all 0.3s;
        }
        
        .nav a:hover {
            background: #667eea;
            color: white;
        }
        
        .section {
            padding: 5rem 0;
        }
        
        .section-title {
            text-align: center;
            font-size: 3rem;
            font-weight: 700;
            margin-bottom: 1rem;
            color: #1a202c;
        }
        
        .section-subtitle {
            text-align: center;
            color: #718096;
            font-size: 1.2rem;
            margin-bottom: 3rem;
            max-width: 600px;
            margin-left: auto;
            margin-right: auto;
        }
        
        .projects-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 2rem;
            margin-top: 3rem;
        }
        
        .project-card {
            background: white;
            border-radius: 20px;
            overflow: hidden;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            transition: all 0.3s ease;
            position: relative;
        }
        
        .project-card:hover {
            transform: translateY(-10px);
            box-shadow: 0 20px 60px rgba(0,0,0,0.15);
        }
        
        .project-card.featured::before {
            content: '⭐ Featured';
            position: absolute;
            top: 1rem;
            right: 1rem;
            background: #f6ad55;
            color: white;
            padding: 0.3rem 0.8rem;
            border-radius: 15px;
            font-size: 0.8rem;
            font-weight: 600;
            z-index: 2;
        }
        
        .project-image {
            width: 100%;
            height: 200px;
            object-fit: cover;
        }
        
        .project-info {
            padding: 2rem;
        }
        
        .project-category {
            display: inline-block;
            background: #e2e8f0;
            color: #4a5568;
            padding: 0.3rem 0.8rem;
            border-radius: 15px;
            font-size: 0.8rem;
            font-weight: 600;
            margin-bottom: 1rem;
        }
        
        .project-title {
            font-size: 1.4rem;
            font-weight: 700;
            margin-bottom: 1rem;
            color: #1a202c;
        }
        
        .project-description {
            color: #718096;
            margin-bottom: 1rem;
            line-height: 1.6;
        }
        
        .project-tech {
            font-size: 0.9rem;
            color: #667eea;
            font-weight: 600;
        }
        
        .team-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 2rem;
            margin-top: 3rem;
        }
        
        .team-card {
            background: white;
            border-radius: 20px;
            padding: 2rem;
            text-align: center;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }
        
        .team-card:hover {
            transform: translateY(-5px);
        }
        
        .team-avatar {
            width: 120px;
            height: 120px;
            border-radius: 50%;
            object-fit: cover;
            margin: 0 auto 1rem;
            border: 4px solid #667eea;
        }
        
        .team-name {
            font-size: 1.3rem;
            font-weight: 700;
            margin-bottom: 0.5rem;
            color: #1a202c;
        }
        
        .team-position {
            color: #667eea;
            font-weight: 600;
            margin-bottom: 1rem;
        }
        
        .team-bio {
            color: #718096;
            line-height: 1.6;
        }
        
        .error-message {
            background: #fed7d7;
            color: #742a2a;
            padding: 1rem;
            border-radius: 8px;
            margin-bottom: 2rem;
        }
        
        .footer {
            background: #1a202c;
            color: white;
            text-align: center;
            padding: 3rem 0;
        }
        
        @media (max-width: 768px) {
            .hero h1 {
                font-size: 2.5rem;
            }
            
            .section-title {
                font-size: 2rem;
            }
            
            .nav ul {
                flex-wrap: wrap;
                gap: 1rem;
            }
        }
    </style>
</head>
<body>
    <nav class="nav">
        <div class="container">
            <ul>
                <li><a href="#home">Home</a></li>
                <li><a href="#projects">Projects</a></li>
                <li><a href="#team">Team</a></li>
                <li><a href="#contact">Contact</a></li>
            </ul>
        </div>
    </nav>
    
    <section class="hero" id="home">
        <div class="container">
            <div class="hero-content">
                <h1>🎨 PixelCraft</h1>
                <p>We craft digital experiences that inspire, engage, and deliver results for forward-thinking brands.</p>
                <a href="#projects" class="cta-button">View Our Work</a>
            </div>
        </div>
    </section>
    
    <section class="section" id="projects">
        <div class="container">
            <?php if (isset($db_error)): ?>
                <div class="error-message">
                    <strong>Database Error:</strong> <?php echo htmlspecialchars($db_error); ?>
                </div>
            <?php endif; ?>
            
            <h2 class="section-title">Our Projects</h2>
            <p class="section-subtitle">Explore our portfolio of innovative digital solutions that have helped businesses transform and grow.</p>
            
            <div class="projects-grid">
                <?php foreach ($projects as $project): ?>
                    <div class="project-card <?php echo $project['featured'] ? 'featured' : ''; ?>">
                        <img src="<?php echo htmlspecialchars($project['image_url']); ?>" 
                             alt="<?php echo htmlspecialchars($project['title']); ?>" 
                             class="project-image">
                        <div class="project-info">
                            <div class="project-category"><?php echo htmlspecialchars($project['category']); ?></div>
                            <h3 class="project-title"><?php echo htmlspecialchars($project['title']); ?></h3>
                            <p class="project-description"><?php echo htmlspecialchars($project['description']); ?></p>
                            <div class="project-tech">Technologies: <?php echo htmlspecialchars($project['technologies']); ?></div>
                        </div>
                    </div>
                <?php endforeach; ?>
            </div>
        </div>
    </section>
    
    <section class="section" id="team" style="background: #f7fafc;">
        <div class="container">
            <h2 class="section-title">Meet Our Team</h2>
            <p class="section-subtitle">Talented professionals dedicated to bringing your vision to life with creativity and technical expertise.</p>
            
            <div class="team-grid">
                <?php foreach ($team as $member): ?>
                    <div class="team-card">
                        <img src="<?php echo htmlspecialchars($member['image_url']); ?>" 
                             alt="<?php echo htmlspecialchars($member['name']); ?>" 
                             class="team-avatar">
                        <h3 class="team-name"><?php echo htmlspecialchars($member['name']); ?></h3>
                        <div class="team-position"><?php echo htmlspecialchars($member['position']); ?></div>
                        <p class="team-bio"><?php echo htmlspecialchars($member['bio']); ?></p>
                    </div>
                <?php endforeach; ?>
            </div>
        </div>
    </section>
    
    <footer class="footer">
        <div class="container">
            <p>&copy; 2024 PixelCraft Digital Agency. Sample Portfolio Site - NixOS Demo</p>
        </div>
    </footer>
</body>
</html>
