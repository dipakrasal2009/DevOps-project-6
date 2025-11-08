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
users = [
    {
        "id": 1,
        "name": "John Doe",
        "email": "john.doe@example.com",
        "role": "admin",
        "created_at": "2024-01-15T10:30:00Z"
    },
    {
        "id": 2,
        "name": "Jane Smith",
        "email": "jane.smith@example.com",
        "role": "user",
        "created_at": "2024-01-16T14:20:00Z"
    },
    {
        "id": 3,
        "name": "Bob Johnson",
        "email": "bob.johnson@example.com",
        "role": "user",
        "created_at": "2024-01-17T09:15:00Z"
    },
    {
        "id": 4,
        "name": "Alice Brown",
        "email": "alice.brown@example.com",
        "role": "moderator",
        "created_at": "2024-01-18T16:45:00Z"
    }
]

@app.route('/api/users', methods=['GET'])
def get_users():
    """Get all users"""
    logger.info("Fetching all users")
    return jsonify(users)

@app.route('/api/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    """Get a specific user by ID"""
    user = next((u for u in users if u['id'] == user_id), None)
    if user:
        logger.info(f"Fetching user {user_id}")
        return jsonify(user)
    else:
        logger.warning(f"User {user_id} not found")
        return jsonify({"error": "User not found"}), 404

@app.route('/api/users', methods=['POST'])
def create_user():
    """Create a new user"""
    data = request.get_json()
    
    if not data or not all(k in data for k in ('name', 'email', 'role')):
        return jsonify({"error": "Missing required fields"}), 400
    
    new_user = {
        "id": max([u['id'] for u in users]) + 1,
        "name": data['name'],
        "email": data['email'],
        "role": data['role'],
        "created_at": datetime.utcnow().isoformat() + "Z"
    }
    
    users.append(new_user)
    logger.info(f"Created new user: {new_user['name']}")
    return jsonify(new_user), 201

@app.route('/api/users/<int:user_id>', methods=['PUT'])
def update_user(user_id):
    """Update a user"""
    user = next((u for u in users if u['id'] == user_id), None)
    if not user:
        return jsonify({"error": "User not found"}), 404
    
    data = request.get_json()
    if not data:
        return jsonify({"error": "No data provided"}), 400
    
    # Update user fields
    for key, value in data.items():
        if key in ['name', 'email', 'role']:
            user[key] = value
    
    logger.info(f"Updated user {user_id}")
    return jsonify(user)

@app.route('/api/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    """Delete a user"""
    global users
    user = next((u for u in users if u['id'] == user_id), None)
    if not user:
        return jsonify({"error": "User not found"}), 404
    
    users = [u for u in users if u['id'] != user_id]
    logger.info(f"Deleted user {user_id}")
    return jsonify({"message": "User deleted successfully"})

@app.route('/api/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'user-service',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0'
    })

@app.route('/api/metrics', methods=['GET'])
def metrics():
    """Prometheus metrics endpoint"""
    return jsonify({
        'user_service_requests_total': len(users) * 10,
        'user_service_users_count': len(users),
        'user_service_uptime_seconds': 3600
    })

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5001))
    debug = os.environ.get('DEBUG', 'False').lower() == 'true'
    app.run(host='0.0.0.0', port=port, debug=debug)
