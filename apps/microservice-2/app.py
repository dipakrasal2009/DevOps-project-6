from flask import Flask, jsonify, request
import os
import logging
from datetime import datetime

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key')

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Mock data for demonstration
products = [
    {
        "id": 1,
        "name": "Laptop Pro",
        "description": "High-performance laptop for professionals",
        "price": 1299.99,
        "category": "Electronics",
        "stock": 50,
        "created_at": "2024-01-15T10:30:00Z"
    },
    {
        "id": 2,
        "name": "Wireless Mouse",
        "description": "Ergonomic wireless mouse with precision tracking",
        "price": 29.99,
        "category": "Accessories",
        "stock": 200,
        "created_at": "2024-01-16T14:20:00Z"
    },
    {
        "id": 3,
        "name": "Mechanical Keyboard",
        "description": "RGB mechanical keyboard with tactile switches",
        "price": 149.99,
        "category": "Accessories",
        "stock": 75,
        "created_at": "2024-01-17T09:15:00Z"
    },
    {
        "id": 4,
        "name": "Monitor 4K",
        "description": "27-inch 4K monitor with HDR support",
        "price": 399.99,
        "category": "Electronics",
        "stock": 30,
        "created_at": "2024-01-18T16:45:00Z"
    },
    {
        "id": 5,
        "name": "Webcam HD",
        "description": "1080p HD webcam with built-in microphone",
        "price": 79.99,
        "category": "Accessories",
        "stock": 100,
        "created_at": "2024-01-19T11:30:00Z"
    }
]

@app.route('/api/products', methods=['GET'])
def get_products():
    """Get all products"""
    logger.info("Fetching all products")
    return jsonify(products)

@app.route('/api/products/<int:product_id>', methods=['GET'])
def get_product(product_id):
    """Get a specific product by ID"""
    product = next((p for p in products if p['id'] == product_id), None)
    if product:
        logger.info(f"Fetching product {product_id}")
        return jsonify(product)
    else:
        logger.warning(f"Product {product_id} not found")
        return jsonify({"error": "Product not found"}), 404

@app.route('/api/products', methods=['POST'])
def create_product():
    """Create a new product"""
    data = request.get_json()
    
    if not data or not all(k in data for k in ('name', 'description', 'price', 'category')):
        return jsonify({"error": "Missing required fields"}), 400
    
    new_product = {
        "id": max([p['id'] for p in products]) + 1,
        "name": data['name'],
        "description": data['description'],
        "price": float(data['price']),
        "category": data['category'],
        "stock": data.get('stock', 0),
        "created_at": datetime.utcnow().isoformat() + "Z"
    }
    
    products.append(new_product)
    logger.info(f"Created new product: {new_product['name']}")
    return jsonify(new_product), 201

@app.route('/api/products/<int:product_id>', methods=['PUT'])
def update_product(product_id):
    """Update a product"""
    product = next((p for p in products if p['id'] == product_id), None)
    if not product:
        return jsonify({"error": "Product not found"}), 404
    
    data = request.get_json()
    if not data:
        return jsonify({"error": "No data provided"}), 400
    
    # Update product fields
    for key, value in data.items():
        if key in ['name', 'description', 'price', 'category', 'stock']:
            if key == 'price':
                product[key] = float(value)
            else:
                product[key] = value
    
    logger.info(f"Updated product {product_id}")
    return jsonify(product)

@app.route('/api/products/<int:product_id>', methods=['DELETE'])
def delete_product(product_id):
    """Delete a product"""
    global products
    product = next((p for p in products if p['id'] == product_id), None)
    if not product:
        return jsonify({"error": "Product not found"}), 404
    
    products = [p for p in products if p['id'] != product_id]
    logger.info(f"Deleted product {product_id}")
    return jsonify({"message": "Product deleted successfully"})

@app.route('/api/products/category/<category>', methods=['GET'])
def get_products_by_category(category):
    """Get products by category"""
    category_products = [p for p in products if p['category'].lower() == category.lower()]
    logger.info(f"Fetching products for category: {category}")
    return jsonify(category_products)

@app.route('/api/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'product-service',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0'
    })

@app.route('/api/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint"""
    return jsonify({
        'product_service_requests_total': len(products) * 15,
        'product_service_products_count': len(products),
        'product_service_uptime_seconds': 3600,
        'product_service_total_value': sum(p['price'] * p['stock'] for p in products)
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5002))
    debug = os.environ.get('DEBUG', 'False').lower() == 'true'
    app.run(host='0.0.0.0', port=port, debug=debug)
