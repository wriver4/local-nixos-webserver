<?php
// Sample Site 1 - E-commerce Demo
$db_config = [
    'host' => 'localhost',
    'username' => 'webuser',
    'password' => 'webpass123',
    'database' => 'sample1_db'
];

try {
    $pdo = new PDO("mysql:host={$db_config['host']};dbname={$db_config['database']}", 
                   $db_config['username'], $db_config['password']);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Create products table
    $pdo->exec("CREATE TABLE IF NOT EXISTS products (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        price DECIMAL(10,2) NOT NULL,
        description TEXT,
        image_url VARCHAR(500),
        category VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");
    
    // Insert sample products
    $count = $pdo->query("SELECT COUNT(*) FROM products")->fetchColumn();
    if ($count == 0) {
        $pdo->exec("INSERT INTO products (name, price, description, image_url, category) VALUES 
            ('Wireless Headphones', 99.99, 'Premium wireless headphones with noise cancellation', 'https://images.pexels.com/photos/3394650/pexels-photo-3394650.jpeg', 'Electronics'),
            ('Smart Watch', 249.99, 'Advanced fitness tracking and notifications', 'https://images.pexels.com/photos/437037/pexels-photo-437037.jpeg', 'Electronics'),
            ('Coffee Maker', 79.99, 'Programmable coffee maker with thermal carafe', 'https://images.pexels.com/photos/324028/pexels-photo-324028.jpeg', 'Appliances'),
            ('Laptop Stand', 39.99, 'Ergonomic aluminum laptop stand', 'https://images.pexels.com/photos/4050315/pexels-photo-4050315.jpeg', 'Accessories'),
            ('Desk Lamp', 59.99, 'LED desk lamp with adjustable brightness', 'https://images.pexels.com/photos/1112598/pexels-photo-1112598.jpeg', 'Lighting'),
            ('Bluetooth Speaker', 129.99, 'Portable waterproof Bluetooth speaker', 'https://images.pexels.com/photos/1649771/pexels-photo-1649771.jpeg', 'Electronics')");
    }
    
    $products = $pdo->query("SELECT * FROM products ORDER BY created_at DESC")->fetchAll(PDO::FETCH_ASSOC);
} catch(PDOException $e) {
    $db_error = "Connection failed: " . $e->getMessage();
    $products = [];
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TechStore - Sample E-commerce Site</title>
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
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 2rem 0;
            text-align: center;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 20px;
        }
        
        .header h1 {
            font-size: 3rem;
            margin-bottom: 0.5rem;
        }
        
        .header p {
            font-size: 1.2rem;
            opacity: 0.9;
        }
        
        .nav {
            background: #fff;
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
            color: #333;
            font-weight: 600;
            padding: 0.5rem 1rem;
            border-radius: 5px;
            transition: background 0.3s;
        }
        
        .nav a:hover {
            background: #f0f0f0;
        }
        
        .main {
            padding: 3rem 0;
        }
        
        .products-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 2rem;
            margin-top: 2rem;
        }
        
        .product-card {
            background: white;
            border-radius: 15px;
            overflow: hidden;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .product-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 20px 40px rgba(0,0,0,0.15);
        }
        
        .product-image {
            width: 100%;
            height: 200px;
            object-fit: cover;
        }
        
        .product-info {
            padding: 1.5rem;
        }
        
        .product-name {
            font-size: 1.3rem;
            font-weight: 700;
            margin-bottom: 0.5rem;
            color: #2d3748;
        }
        
        .product-price {
            font-size: 1.5rem;
            font-weight: 700;
            color: #667eea;
            margin-bottom: 0.5rem;
        }
        
        .product-description {
            color: #718096;
            margin-bottom: 1rem;
            line-height: 1.5;
        }
        
        .product-category {
            display: inline-block;
            background: #e2e8f0;
            color: #4a5568;
            padding: 0.25rem 0.75rem;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: 600;
            margin-bottom: 1rem;
        }
        
        .btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 0.75rem 1.5rem;
            border-radius: 8px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s;
            width: 100%;
        }
        
        .btn:hover {
            transform: scale(1.02);
        }
        
        .section-title {
            text-align: center;
            font-size: 2.5rem;
            color: #2d3748;
            margin-bottom: 1rem;
        }
        
        .section-subtitle {
            text-align: center;
            color: #718096;
            font-size: 1.1rem;
            margin-bottom: 2rem;
        }
        
        .error-message {
            background: #fed7d7;
            color: #742a2a;
            padding: 1rem;
            border-radius: 8px;
            margin-bottom: 2rem;
        }
        
        .footer {
            background: #2d3748;
            color: white;
            text-align: center;
            padding: 2rem 0;
            margin-top: 4rem;
        }
    </style>
</head>
<body>
    <header class="header">
        <div class="container">
            <h1>🛍️ TechStore</h1>
            <p>Your one-stop shop for premium tech products</p>
        </div>
    </header>
    
    <nav class="nav">
        <div class="container">
            <ul>
                <li><a href="#home">Home</a></li>
                <li><a href="#products">Products</a></li>
                <li><a href="#about">About</a></li>
                <li><a href="#contact">Contact</a></li>
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
            
            <h2 class="section-title">Featured Products</h2>
            <p class="section-subtitle">Discover our latest collection of premium tech products</p>
            
            <div class="products-grid">
                <?php foreach ($products as $product): ?>
                    <div class="product-card">
                        <img src="<?php echo htmlspecialchars($product['image_url']); ?>" 
                             alt="<?php echo htmlspecialchars($product['name']); ?>" 
                             class="product-image">
                        <div class="product-info">
                            <div class="product-category"><?php echo htmlspecialchars($product['category']); ?></div>
                            <h3 class="product-name"><?php echo htmlspecialchars($product['name']); ?></h3>
                            <div class="product-price">$<?php echo number_format($product['price'], 2); ?></div>
                            <p class="product-description"><?php echo htmlspecialchars($product['description']); ?></p>
                            <button class="btn">Add to Cart</button>
                        </div>
                    </div>
                <?php endforeach; ?>
            </div>
        </div>
    </main>
    
    <footer class="footer">
        <div class="container">
            <p>&copy; 2024 TechStore. Sample E-commerce Site - NixOS Demo</p>
        </div>
    </footer>
</body>
</html>
