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