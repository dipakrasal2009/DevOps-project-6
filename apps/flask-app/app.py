from flask import Flask, render_template, request, jsonify, redirect, url_for
import requests
import os
import logging
from datetime import datetime

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key')

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Microservices endpoints
USER_SERVICE_URL = os.environ.get('USER_SERVICE_URL', 'http://user-service:5001')
PRODUCT_SERVICE_URL = os.environ.get('PRODUCT_SERVICE_URL', 'http://product-service:5002')

@app.route('/')
def index():
    """Main dashboard page"""
    try:
        # Get users from user service
        users_response = requests.get(f"{USER_SERVICE_URL}/api/users", timeout=5)
        users = users_response.json() if users_response.status_code == 200 else []
        
        # Get products from product service
        products_response = requests.get(f"{PRODUCT_SERVICE_URL}/api/products", timeout=5)
        products = products_response.json() if products_response.status_code == 200 else []
        
        return render_template('index.html', users=users, products=products)
    except Exception as e:
        logger.error(f"Error fetching data: {e}")
        return render_template('index.html', users=[], products=[], error=str(e))

@app.route('/users')
def users():
    """Users management page"""
    try:
        response = requests.get(f"{USER_SERVICE_URL}/api/users", timeout=5)
        if response.status_code == 200:
            users = response.json()
            return render_template('users.html', users=users)
        else:
            return render_template('users.html', users=[], error="Failed to fetch users")
    except Exception as e:
        logger.error(f"Error fetching users: {e}")
        return render_template('users.html', users=[], error=str(e))

@app.route('/products')
def products():
    """Products management page"""
    try:
        response = requests.get(f"{PRODUCT_SERVICE_URL}/api/products", timeout=5)
        if response.status_code == 200:
            products = response.json()
            return render_template('products.html', products=products)
        else:
            return render_template('products.html', products=[], error="Failed to fetch products")
    except Exception as e:
        logger.error(f"Error fetching products: {e}")
        return render_template('products.html', products=[], error=str(e))

@app.route('/api/health')
def health():
    """Health check endpoint"""
    health_status = {
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0',
        'services': {}
    }
    
    # Check user service
    try:
        user_response = requests.get(f"{USER_SERVICE_URL}/api/health", timeout=2)
        health_status['services']['user_service'] = 'healthy' if user_response.status_code == 200 else 'unhealthy'
    except:
        health_status['services']['user_service'] = 'unhealthy'
    
    # Check product service
    try:
        product_response = requests.get(f"{PRODUCT_SERVICE_URL}/api/health", timeout=2)
        health_status['services']['product_service'] = 'healthy' if product_response.status_code == 200 else 'unhealthy'
    except:
        health_status['services']['product_service'] = 'unhealthy'
    
    return jsonify(health_status)

@app.route('/api/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    metrics_data = {
        'flask_app_requests_total': 1,
        'flask_app_uptime_seconds': 3600,
        'microservices_connected': 2
    }
    return jsonify(metrics_data)

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('DEBUG', 'False').lower() == 'true'
    app.run(host='0.0.0.0', port=port, debug=debug)
