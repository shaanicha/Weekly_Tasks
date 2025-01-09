#!/bin/bash

# Exit on error
set -e

# Remove existing directory if it exists and create new structure
rm -rf ecommerce-app
mkdir -p ecommerce-app
cd ecommerce-app

# Create project structure
mkdir -p static/{css,js,images} templates database
chmod 777 database  # Set proper permissions for database directory

# Create app.py
cat > app.py << 'EOF'
from flask import Flask, render_template, jsonify, request, g
import sqlite3
from contextlib import contextmanager
from datetime import datetime

app = Flask(__name__)

DATABASE = "database/products.db"

@contextmanager
def get_db():
    db = sqlite3.connect(DATABASE)
    db.row_factory = sqlite3.Row
    try:
        yield db
    finally:
        db.close()

def init_db():
    with get_db() as conn:
        c = conn.cursor()
        # Create products table
        c.execute("""
            CREATE TABLE IF NOT EXISTS products
            (id INTEGER PRIMARY KEY AUTOINCREMENT,
             name TEXT NOT NULL,
             price REAL NOT NULL,
             description TEXT,
             image_url TEXT,
             created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)
        """)
        
        # Create orders table
        c.execute("""
            CREATE TABLE IF NOT EXISTS orders
            (id INTEGER PRIMARY KEY AUTOINCREMENT,
             user_id INTEGER NOT NULL,
             product_id INTEGER NOT NULL,
             quantity INTEGER NOT NULL,
             total_price REAL NOT NULL,
             status TEXT DEFAULT "pending",
             created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
             FOREIGN KEY (product_id) REFERENCES products (id))
        """)
        
        # Add sample products if none exist
        c.execute("SELECT COUNT(*) FROM products")
        if c.fetchone()[0] == 0:
            sample_products = [
                ("Laptop", 999.99, "High-performance laptop", "images/laptop.jpg"),
                ("Smartphone", 699.99, "Latest smartphone", "images/phone.jpg"),
                ("Headphones", 199.99, "Wireless headphones", "images/headphones.jpg")
            ]
            c.executemany("""
                INSERT INTO products (name, price, description, image_url) 
                VALUES (?, ?, ?, ?)""", sample_products)
        
        conn.commit()

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/orders")
def orders():
    return render_template("orders.html")

@app.route("/api/products")
def get_products():
    try:
        with get_db() as conn:
            c = conn.cursor()
            c.execute("SELECT * FROM products ORDER BY created_at DESC")
            products = [dict(row) for row in c.fetchall()]
            return jsonify({"success": True, "products": products})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route("/api/orders", methods=["POST"])
def create_order():
    try:
        data = request.get_json()
        user_id = data.get("user_id", 1)  # Default user_id for demo
        product_id = data.get("product_id")
        quantity = data.get("quantity", 1)

        if not product_id:
            return jsonify({"success": False, "error": "Product ID is required"}), 400

        with get_db() as conn:
            c = conn.cursor()
            
            # Get product price
            c.execute("SELECT price FROM products WHERE id = ?", (product_id,))
            result = c.fetchone()
            if not result:
                return jsonify({"success": False, "error": "Product not found"}), 404
            
            price = result["price"]
            total_price = price * quantity

            # Create order
            c.execute("""
                INSERT INTO orders (user_id, product_id, quantity, total_price)
                VALUES (?, ?, ?, ?)
            """, (user_id, product_id, quantity, total_price))
            
            order_id = c.lastrowid
            conn.commit()

            return jsonify({
                "success": True,
                "order_id": order_id,
                "total_price": total_price
            }), 201

    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@app.route("/api/orders", methods=["GET"])
def get_orders():
    try:
        with get_db() as conn:
            c = conn.cursor()
            c.execute("""
                SELECT o.*, p.name as product_name, p.price as unit_price
                FROM orders o
                JOIN products p ON o.product_id = p.id
                ORDER BY o.created_at DESC
            """)
            orders = [dict(row) for row in c.fetchall()]
            return jsonify({"success": True, "orders": orders})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)
EOF

# Create index.html
cat > templates/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>E-commerce Store</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}">
</head>
<body>
    <header>
        <h1>Our Products</h1>
        <nav>
            <a href="/" class="nav-link">Products</a>
            <a href="/orders" class="nav-link">Orders</a>
        </nav>
    </header>
    <main>
        <div id="loading" class="loading">Loading products...</div>
        <div id="error" class="error"></div>
        <div id="success" class="success"></div>
        <div id="products-container"></div>
    </main>
    <script src="{{ url_for('static', filename='js/main.js') }}"></script>
</body>
</html>
EOF

# Create orders.html
cat > templates/orders.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Orders - E-commerce Store</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}">
</head>
<body>
    <header>
        <h1>Orders</h1>
        <nav>
            <a href="/" class="nav-link">Products</a>
            <a href="/orders" class="nav-link">Orders</a>
        </nav>
    </header>
    <main>
        <div id="loading" class="loading">Loading orders...</div>
        <div id="error" class="error"></div>
        <div id="orders-container"></div>
    </main>
    <script src="{{ url_for('static', filename='js/orders.js') }}"></script>
</body>
</html>
EOF

# Create main.js
cat > static/js/main.js << 'EOF'
document.addEventListener("DOMContentLoaded", () => {
    const loadingEl = document.getElementById("loading");
    const errorEl = document.getElementById("error");
    const successEl = document.getElementById("success");
    const containerEl = document.getElementById("products-container");

    async function buyProduct(productId) {
        try {
            const response = await fetch("/api/orders", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({
                    product_id: productId,
                    quantity: 1,
                }),
            });

            const data = await response.json();

            if (!data.success) {
                throw new Error(data.error || "Failed to place order");
            }

            successEl.textContent = `Order placed successfully! Total: $${data.total_price.toFixed(2)}`;
            successEl.style.display = "block";
            setTimeout(() => {
                successEl.style.display = "none";
            }, 3000);

        } catch (error) {
            errorEl.textContent = error.message;
            errorEl.style.display = "block";
            setTimeout(() => {
                errorEl.style.display = "none";
            }, 3000);
        }
    }

    async function loadProducts() {
        try {
            loadingEl.style.display = "block";
            errorEl.style.display = "none";
            containerEl.innerHTML = "";

            const response = await fetch("/api/products");
            const data = await response.json();

            if (!data.success) {
                throw new Error(data.error || "Failed to load products");
            }

            data.products.forEach(product => {
                const productCard = document.createElement("div");
                productCard.className = "product-card";
                productCard.innerHTML = `
                    <img src="${product.image_url}" alt="${product.name}" class="product-image">
                    <h2>${product.name}</h2>
                    <p class="price">$${product.price.toFixed(2)}</p>
                    <p class="description">${product.description}</p>
                    <button class="buy-button" onclick="buyProduct(${product.id})">Buy Now</button>
                `;
                containerEl.appendChild(productCard);
            });
        } catch (error) {
            errorEl.textContent = error.message;
            errorEl.style.display = "block";
        } finally {
            loadingEl.style.display = "none";
        }
    }

    window.buyProduct = buyProduct;
    loadProducts();
});
EOF

# Create orders.js
cat > static/js/orders.js << 'EOF'
document.addEventListener("DOMContentLoaded", () => {
    const loadingEl = document.getElementById("loading");
    const errorEl = document.getElementById("error");
    const containerEl = document.getElementById("orders-container");

    async function loadOrders() {
        try {
            loadingEl.style.display = "block";
            errorEl.style.display = "none";
            containerEl.innerHTML = "";

            const response = await fetch("/api/orders");
            const data = await response.json();

            if (!data.success) {
                throw new Error(data.error || "Failed to load orders");
            }

            if (data.orders.length === 0) {
                containerEl.innerHTML = "<p class=\"no-orders\">No orders found</p>";
                return;
            }

            const table = document.createElement("table");
            table.className = "orders-table";
            table.innerHTML = `
                <thead>
                    <tr>
                        <th>Order ID</th>
                        <th>Product</th>
                        <th>Quantity</th>
                        <th>Unit Price</th>
                        <th>Total Price</th>
                        <th>Status</th>
                        <th>Date</th>
                    </tr>
                </thead>
                <tbody>
                    ${data.orders.map(order => `
                        <tr>
                            <td>${order.id}</td>
                            <td>${order.product_name}</td>
                            <td>${order.quantity}</td>
                            <td>$${order.unit_price.toFixed(2)}</td>
                            <td>$${order.total_price.toFixed(2)}</td>
                            <td>${order.status}</td>
                            <td>${new Date(order.created_at).toLocaleString()}</td>
                        </tr>
                    `).join("")}
                </tbody>
            `;
            containerEl.appendChild(table);
        } catch (error) {
            errorEl.textContent = error.message;
            errorEl.style.display = "block";
        } finally {
            loadingEl.style.display = "none";
        }
    }

    loadOrders();
});
EOF
echo '* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: system-ui, -apple-system, sans-serif;
    line-height: 1.6;
    padding: 20px;
    background-color: #f5f5f5;
}

header {
    text-align: center;
    margin-bottom: 30px;
    padding: 20px;
    background-color: #fff;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

nav {
    margin-top: 15px;
}

.nav-link {
    display: inline-block;
    padding: 8px 16px;
    margin: 0 10px;
    color: #1f2937;
    text-decoration: none;
    border-radius: 6px;
    transition: background-color 0.2s;
}

.nav-link:hover {
    background-color: #f3f4f6;
}

.loading, .error, .success {
    display: none;
    text-align: center;
    padding: 20px;
    margin: 20px 0;
    border-radius: 8px;
}

.error {
    background-color: #fee2e2;
    color: #dc2626;
}

.success {
    background-color: #d1fae5;
    color: #059669;
}

#products-container {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 24px;
    padding: 20px;
}

.product-card {
    background: #fff;
    border-radius: 12px;
    padding: 20px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    transition: transform 0.2s;
}

.product-card:hover {
    transform: translateY(-4px);
}

.product-image {
    width: 100%;
    height: 200px;
    object-fit: cover;
    border-radius: 8px;
    margin-bottom: 15px;
}

.product-card h2 {
    margin-bottom: 10px;
    color: #1f2937;
}

.price {
    font-size: 1.25em;
    font-weight: 600;
    color: #059669;
    margin: 10px 0;
}

.description {
    color: #6b7280;
    margin-bottom: 15px;
}

.buy-button {
    width: 100%;
    padding: 12px;
    background-color: #2563eb;
    color: white;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 1em;
    transition: background-color 0.2s;
}

.buy-button:hover {
    background-color: #1d4ed8;
}

.orders-table {
    width: 100%;
    border-collapse: collapse;
    background-color: white;
    border-radius: 8px;
    overflow: hidden;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    margin: 20px 0;
}

.orders-table th,
.orders-table td {
    padding: 12px 16px;
    text-align: left;
    border-bottom: 1px solid #e5e7eb;
}

.orders-table th {
    background-color: #f8fafc;
    font-weight: 600;
    color: #1f2937;
}

.orders-table tr:last-child td {
    border-bottom: none;
}

.orders-table tbody tr:hover {
    background-color: #f8fafc;
}

.no-orders {
    text-align: center;
    padding: 40px;
    color: #6b7280;
    background-color: white;
    border-radius: 8px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

/* Responsive styles */
@media (max-width: 768px) {
    .orders-table {
        display: block;
        overflow-x: auto;
        white-space: nowrap;
    }
    
    .product-card {
        margin: 10px;
    }
    
    body {
        padding: 10px;
    }
}' > static/css/style.css

# Create updated requirements.txt with all necessary packages
echo 'Flask==2.3.3
Werkzeug==2.3.7
itsdangerous==2.1.2
click==8.1.7
Jinja2==3.1.2
MarkupSafe==2.1.3
python-dotenv==1.0.0
SQLAlchemy==2.0.25' > requirements.txt

# Create improved Dockerfile with multi-stage build
echo 'FROM python:3.11-slim as builder

WORKDIR /app

# Install build dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Final stage
FROM python:3.11-slim

# Create non-root user
RUN useradd -m -r app

WORKDIR /app

# Copy only necessary files from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages/ /usr/local/lib/python3.11/site-packages/
COPY . .

# Set proper permissions
RUN chown -R app:app /app

# Switch to non-root user
USER app

EXPOSE 5000

CMD ["python", "app.py"]' > Dockerfile

# Create improved docker-compose.yml with better configuration
echo 'version: "3.8"

services:
  web:
    build: .
    ports:
      - "5000:5000"
    volumes:
      - ./database:/app/database
      - ./static:/app/static
    environment:
      - FLASK_ENV=development
      - PYTHONUNBUFFERED=1
      - FLASK_DEBUG=1
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          cpus: "0.50"
          memory: 512M' > docker-compose.yml

# Create comprehensive .gitignore
echo '# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Virtual Environment
env/
venv/
ENV/

# Database
*.db
*.sqlite3

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Environment variables
.env
.env.local

# Logs
*.log
logs/

# Docker
.docker/
docker-compose.override.yml' > .gitignore

# Create an empty .env file for environment variables
echo 'FLASK_ENV=development
FLASK_DEBUG=1
DATABASE_URL=sqlite:///database/products.db' > .env

# Create empty directories for static files
mkdir -p static/images

# Create a simple README.md
echo '# E-commerce Application

A simple e-commerce application built with Flask and SQLite.

## Features

- Product listing
- Order management
- Responsive design
- Docker support

## Setup

1. Clone the repository
2. Run `docker-compose up --build`
3. Visit http://localhost:5000 in your browser

## Development

To run in development mode:

```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
python app.py
```

## License

MIT' > README.md

echo "Project structure created successfully!"
echo "To run the project:"
echo "1. cd ecommerce-app"
echo "2. docker-compose up --build"
echo "3. Visit http://localhost:5000 in your browser"
echo ""
echo "The application now includes:"
echo "- Product listing with buy buttons"
echo "- Order management system"
echo "- Responsive design"
echo "- Docker support with proper security measures"
echo "- Development environment configuration"
root@instance-20250106-110203:/home/prasadsanban# 
