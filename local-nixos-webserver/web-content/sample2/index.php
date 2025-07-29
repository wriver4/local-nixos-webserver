<?php
// Sample Site 2 - Blog/News Site
$db_config = [
    'host' => 'localhost',
    'username' => 'webuser',
    'password' => 'webpass123',
    'database' => 'sample2_db'
];

try {
    $pdo = new PDO("mysql:host={$db_config['host']};dbname={$db_config['database']}", 
                   $db_config['username'], $db_config['password']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Create articles table
    $pdo->exec("CREATE TABLE IF NOT EXISTS articles (
        id INT AUTO_INCREMENT PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        content TEXT NOT NULL,
        author VARCHAR(100) NOT NULL,
        category VARCHAR(50),
        image_url VARCHAR(500),
        published_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        views INT DEFAULT 0
    )");
    
    // Insert sample articles
    $count = $pdo->query("SELECT COUNT(*) FROM articles")->fetchColumn();
    if ($count == 0) {
        $pdo->exec("INSERT INTO articles (title, content, author, category, image_url, views) VALUES 
            ('The Future of Web Development', 'Web development continues to evolve at a rapid pace. From server-side rendering to edge computing, developers are constantly adapting to new paradigms. Modern frameworks like React, Vue, and Svelte are pushing the boundaries of what''s possible in the browser, while technologies like WebAssembly promise to bring near-native performance to web applications.', 'Sarah Johnson', 'Technology', 'https://images.pexels.com/photos/270348/pexels-photo-270348.jpeg', 1247),
            ('Sustainable Tech: Green Computing Solutions', 'As environmental concerns grow, the tech industry is focusing on sustainable solutions. From energy-efficient data centers to biodegradable electronics, companies are innovating to reduce their carbon footprint. Cloud providers are investing heavily in renewable energy, and manufacturers are exploring new materials that minimize environmental impact.', 'Michael Chen', 'Environment', 'https://images.pexels.com/photos/414837/pexels-photo-414837.jpeg', 892),
            ('AI and Machine Learning Trends 2024', 'Artificial Intelligence continues to transform industries across the board. From healthcare diagnostics to autonomous vehicles, AI applications are becoming more sophisticated and accessible. The democratization of AI tools means that smaller companies can now leverage machine learning capabilities that were once exclusive to tech giants.', 'Dr. Emily Rodriguez', 'AI/ML', 'https://images.pexels.com/photos/8386440/pexels-photo-8386440.jpeg', 2156),
            ('Cybersecurity in the Modern Age', 'With increasing digitization comes greater security challenges. Organizations must adapt to evolving threats while maintaining user experience. Zero-trust architecture, multi-factor authentication, and AI-powered threat detection are becoming standard practices in enterprise security strategies.', 'James Wilson', 'Security', 'https://images.pexels.com/photos/60504/security-protection-anti-virus-software-60504.jpeg', 1543),
            ('The Rise of Remote Work Technology', 'Remote work has fundamentally changed how we collaborate. Video conferencing, project management tools, and virtual reality meetings are reshaping the workplace. Companies are investing in technologies that enable seamless remote collaboration while maintaining team cohesion and productivity.', 'Lisa Park', 'Workplace', 'https://images.pexels.com/photos/4050315/pexels-photo-4050315.jpeg', 967)");
    }
    
    $articles = $pdo->query("SELECT * FROM articles ORDER BY published_at DESC")->fetchAll(PDO::FETCH_ASSOC);
} catch(PDOException $e) {
    $db_error = "Connection failed: " . $e->getMessage();
    $articles = [];
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TechInsights - Technology News & Articles</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Georgia', 'Times New Roman', serif;
            line-height: 1.7;
            color: #2c3e50;
            background: #f8f9fa;
        }
        
        .header {
            background: linear-gradient(135deg, #2c3e50 0%, #3498db 100%);
            color: white;
            padding: 3rem 0;
            text-align: center;
        }
        
        .container {
            max-width: 1000px;
            margin: 0 auto;
            padding: 0 20px;
        }
        
        .header h1 {
            font-size: 3.5rem;
            margin-bottom: 0.5rem;
            font-weight: 300;
        }
        
        .header p {
            font-size: 1.3rem;
            opacity: 0.9;
            font-style: italic;
        }
        
        .nav {
            background: white;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            padding: 1rem 0;
            position: sticky;
            top: 0;
            z-index: 100;
        }
        
        .nav ul {
            list-style: none;
            display: flex;
            justify-content: center;
            gap: 2rem;
        }
        
        .nav a {
            text-decoration: none;
            color: #2c3e50;
            font-weight: 600;
            padding: 0.5rem 1rem;
            border-radius: 5px;
            transition: all 0.3s;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        
        .nav a:hover {
            background: #3498db;
            color: white;
        }
        
        .main {
            padding: 3rem 0;
        }
        
        .articles-grid {
            display: grid;
            gap: 2rem;
        }
        
        .article-card {
            background: white;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 5px 20px rgba(0,0,0,0.08);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
            display: grid;
            grid-template-columns: 300px 1fr;
            min-height: 200px;
        }
        
        .article-card:hover {
            transform: translateY(-3px);
            box-shadow: 0 10px 30px rgba(0,0,0,0.12);
        }
        
        .article-image {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        
        .article-content {
            padding: 2rem;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
        }
        
        .article-category {
            display: inline-block;
            background: #3498db;
            color: white;
            padding: 0.3rem 0.8rem;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: 600;
            margin-bottom: 1rem;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            width: fit-content;
        }
        
        .article-title {
            font-size: 1.5rem;
            font-weight: 700;
            margin-bottom: 1rem;
            color: #2c3e50;
            line-height: 1.3;
        }
        
        .article-excerpt {
            color: #5a6c7d;
            margin-bottom: 1.5rem;
            line-height: 1.6;
            display: -webkit-box;
            -webkit-line-clamp: 3;
            -webkit-box-orient: vertical;
            overflow: hidden;
        }
        
        .article-meta {
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 0.9rem;
            color: #7f8c8d;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        
        .article-author {
            font-weight: 600;
        }
        
        .article-views {
            display: flex;
            align-items: center;
            gap: 0.3rem;
        }
        
        .section-title {
            text-align: center;
            font-size: 2.5rem;
            color: #2c3e50;
            margin-bottom: 1rem;
            font-weight: 300;
        }
        
        .section-subtitle {
            text-align: center;
            color: #7f8c8d;
            font-size: 1.1rem;
            margin-bottom: 3rem;
            font-style: italic;
        }
        
        .error-message {
            background: #e74c3c;
            color: white;
            padding: 1rem;
            border-radius: 8px;
            margin-bottom: 2rem;
        }
        
        .footer {
            background: #2c3e50;
            color: white;
            text-align: center;
            padding: 2rem 0;
            margin-top: 4rem;
        }
        
        @media (max-width: 768px) {
            .article-card {
                grid-template-columns: 1fr;
            }
            
            .article-image {
                height: 200px;
            }
            
            .header h1 {
                font-size: 2.5rem;
            }
        }
    </style>
</head>
<body>
    <header class="header">
        <div class="container">
            <h1>📰 TechInsights</h1>
            <p>Exploring the intersection of technology and innovation</p>
        </div>
    </header>
    
    <nav class="nav">
        <div class="container">
            <ul>
                <li><a href="#home">Home</a></li>
                <li><a href="#technology">Technology</a></li>
                <li><a href="#ai">AI/ML</a></li>
                <li><a href="#security">Security</a></li>
                <li><a href="#about">About</a></li>
            </ul>
        </div>
    </nav>
    
    <main class="main">
        <div class="container">
            <?php if (isset($db_error)): ?>
                <div class="error-message">
                    <strong>Database Error:</strong> <?php echo htmlspecialchars($db_error); ?>
                </div>
            <?php endif; ?>
            
            <h2 class="section-title">Latest Articles</h2>
            <p class="section-subtitle">Stay informed with our curated technology insights</p>
            
            <div class="articles-grid">
                <?php foreach ($articles as $article): ?>
                    <article class="article-card">
                        <img src="<?php echo htmlspecialchars($article['image_url']); ?>" 
                             alt="<?php echo htmlspecialchars($article['title']); ?>" 
                             class="article-image">
                        <div class="article-content">
                            <div>
                                <div class="article-category"><?php echo htmlspecialchars($article['category']); ?></div>
                                <h3 class="article-title"><?php echo htmlspecialchars($article['title']); ?></h3>
                                <p class="article-excerpt"><?php echo htmlspecialchars(substr($article['content'], 0, 200)) . '...'; ?></p>
                            </div>
                            <div class="article-meta">
                                <span class="article-author">By <?php echo htmlspecialchars($article['author']); ?></span>
                                <span class="article-views">
                                    👁️ <?php echo number_format($article['views']); ?> views
                                </span>
                            </div>
                        </div>
                    </article>
                <?php endforeach; ?>
            </div>
        </div>
    </main>
    
    <footer class="footer">
        <div class="container">
            <p>&copy; 2024 TechInsights. Sample News Site - NixOS Demo</p>
        </div>
    </footer>
</body>
</html>
