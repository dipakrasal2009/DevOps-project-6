# API Reference

This document provides comprehensive API documentation for all services in the DevOps Pipeline.

## Flask Web Application

### Base URL
```
http://flask-app.local
```

### Endpoints

#### Health Check
```http
GET /api/health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-20T10:30:00Z",
  "version": "1.0.0",
  "services": {
    "user_service": "healthy",
    "product_service": "healthy"
  }
}
```

#### Metrics
```http
GET /api/metrics
```

**Response:**
```json
{
  "flask_app_requests_total": 1,
  "flask_app_uptime_seconds": 3600,
  "microservices_connected": 2
}
```

#### Dashboard
```http
GET /
```

**Response:** HTML page with dashboard

#### Users Page
```http
GET /users
```

**Response:** HTML page with users management

#### Products Page
```http
GET /products
```

**Response:** HTML page with products management

## User Service

### Base URL
```
http://user-service:5001
```

### Endpoints

#### Health Check
```http
GET /api/health
```

**Response:**
```json
{
  "status": "healthy",
  "service": "user-service",
  "timestamp": "2024-01-20T10:30:00Z",
  "version": "1.0.0"
}
```

#### Get All Users
```http
GET /api/users
```

**Response:**
```json
[
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
  }
]
```

#### Get User by ID
```http
GET /api/users/{user_id}
```

**Parameters:**
- `user_id` (integer): User ID

**Response:**
```json
{
  "id": 1,
  "name": "John Doe",
  "email": "john.doe@example.com",
  "role": "admin",
  "created_at": "2024-01-15T10:30:00Z"
}
```

**Error Response (404):**
```json
{
  "error": "User not found"
}
```

#### Create User
```http
POST /api/users
```

**Request Body:**
```json
{
  "name": "New User",
  "email": "new.user@example.com",
  "role": "user"
}
```

**Response (201):**
```json
{
  "id": 3,
  "name": "New User",
  "email": "new.user@example.com",
  "role": "user",
  "created_at": "2024-01-20T10:30:00Z"
}
```

**Error Response (400):**
```json
{
  "error": "Missing required fields"
}
```

#### Update User
```http
PUT /api/users/{user_id}
```

**Parameters:**
- `user_id` (integer): User ID

**Request Body:**
```json
{
  "name": "Updated Name",
  "email": "updated@example.com",
  "role": "moderator"
}
```

**Response:**
```json
{
  "id": 1,
  "name": "Updated Name",
  "email": "updated@example.com",
  "role": "moderator",
  "created_at": "2024-01-15T10:30:00Z"
}
```

#### Delete User
```http
DELETE /api/users/{user_id}
```

**Parameters:**
- `user_id` (integer): User ID

**Response:**
```json
{
  "message": "User deleted successfully"
}
```

#### Metrics
```http
GET /api/metrics
```

**Response:**
```json
{
  "user_service_requests_total": 10,
  "user_service_users_count": 4,
  "user_service_uptime_seconds": 3600
}
```

## Product Service

### Base URL
```
http://product-service:5002
```

### Endpoints

#### Health Check
```http
GET /api/health
```

**Response:**
```json
{
  "status": "healthy",
  "service": "product-service",
  "timestamp": "2024-01-20T10:30:00Z",
  "version": "1.0.0"
}
```

#### Get All Products
```http
GET /api/products
```

**Response:**
```json
[
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
  }
]
```

#### Get Product by ID
```http
GET /api/products/{product_id}
```

**Parameters:**
- `product_id` (integer): Product ID

**Response:**
```json
{
  "id": 1,
  "name": "Laptop Pro",
  "description": "High-performance laptop for professionals",
  "price": 1299.99,
  "category": "Electronics",
  "stock": 50,
  "created_at": "2024-01-15T10:30:00Z"
}
```

**Error Response (404):**
```json
{
  "error": "Product not found"
}
```

#### Create Product
```http
POST /api/products
```

**Request Body:**
```json
{
  "name": "New Product",
  "description": "Product description",
  "price": 99.99,
  "category": "Electronics",
  "stock": 10
}
```

**Response (201):**
```json
{
  "id": 3,
  "name": "New Product",
  "description": "Product description",
  "price": 99.99,
  "category": "Electronics",
  "stock": 10,
  "created_at": "2024-01-20T10:30:00Z"
}
```

**Error Response (400):**
```json
{
  "error": "Missing required fields"
}
```

#### Update Product
```http
PUT /api/products/{product_id}
```

**Parameters:**
- `product_id` (integer): Product ID

**Request Body:**
```json
{
  "name": "Updated Product",
  "description": "Updated description",
  "price": 149.99,
  "category": "Accessories",
  "stock": 25
}
```

**Response:**
```json
{
  "id": 1,
  "name": "Updated Product",
  "description": "Updated description",
  "price": 149.99,
  "category": "Accessories",
  "stock": 25,
  "created_at": "2024-01-15T10:30:00Z"
}
```

#### Delete Product
```http
DELETE /api/products/{product_id}
```

**Parameters:**
- `product_id` (integer): Product ID

**Response:**
```json
{
  "message": "Product deleted successfully"
}
```

#### Get Products by Category
```http
GET /api/products/category/{category}
```

**Parameters:**
- `category` (string): Product category

**Response:**
```json
[
  {
    "id": 1,
    "name": "Laptop Pro",
    "description": "High-performance laptop for professionals",
    "price": 1299.99,
    "category": "Electronics",
    "stock": 50,
    "created_at": "2024-01-15T10:30:00Z"
  }
]
```

#### Metrics
```http
GET /api/metrics
```

**Response:**
```json
{
  "product_service_requests_total": 15,
  "product_service_products_count": 5,
  "product_service_uptime_seconds": 3600,
  "product_service_total_value": 50000.00
}
```

## Error Handling

### Standard Error Responses

#### 400 Bad Request
```json
{
  "error": "Missing required fields"
}
```

#### 404 Not Found
```json
{
  "error": "Resource not found"
}
```

#### 500 Internal Server Error
```json
{
  "error": "Internal server error"
}
```

### Error Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request |
| 404 | Not Found |
| 500 | Internal Server Error |

## Authentication

### Current Implementation
The current implementation uses simple secret-based authentication for demonstration purposes.

### Production Considerations
For production deployment, consider implementing:
- JWT tokens
- OAuth 2.0
- API keys
- Rate limiting
- CORS configuration

## Rate Limiting

### Current Implementation
No rate limiting is currently implemented.

### Production Recommendations
```python
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)

@app.route('/api/users')
@limiter.limit("10 per minute")
def get_users():
    # Implementation
    pass
```

## CORS Configuration

### Current Implementation
CORS is not configured.

### Production Configuration
```python
from flask_cors import CORS

CORS(app, resources={
    r"/api/*": {
        "origins": ["https://yourdomain.com"],
        "methods": ["GET", "POST", "PUT", "DELETE"],
        "allow_headers": ["Content-Type", "Authorization"]
    }
})
```

## API Versioning

### Current Implementation
No versioning is currently implemented.

### Recommended Approach
```python
# URL-based versioning
@app.route('/api/v1/users')
def get_users_v1():
    # Implementation
    pass

@app.route('/api/v2/users')
def get_users_v2():
    # Implementation
    pass
```

## Testing

### Unit Tests
```python
import unittest
from app import app

class TestUserService(unittest.TestCase):
    def setUp(self):
        self.app = app.test_client()
    
    def test_get_users(self):
        response = self.app.get('/api/users')
        self.assertEqual(response.status_code, 200)
        self.assertIsInstance(response.json, list)
```

### Integration Tests
```python
import requests

def test_user_service_integration():
    response = requests.get('http://user-service:5001/api/users')
    assert response.status_code == 200
    assert isinstance(response.json(), list)
```

## Monitoring

### Health Checks
All services implement health check endpoints:
- Flask App: `/api/health`
- User Service: `/api/health`
- Product Service: `/api/health`

### Metrics
All services expose metrics endpoints:
- Flask App: `/api/metrics`
- User Service: `/api/metrics`
- Product Service: `/api/metrics`

### Logging
```python
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Log API calls
@app.before_request
def log_request_info():
    logger.info(f"Request: {request.method} {request.url}")
```

## Next Steps

1. **Review Architecture**: Understand the [Architecture Overview](architecture.md)
2. **Security**: Check [Security Guide](security.md)
3. **Monitoring**: Review [Monitoring Guide](monitoring.md)
4. **Troubleshooting**: Refer to [Troubleshooting Guide](troubleshooting.md)
5. **Operational Procedures**: Review [Runbooks](runbooks/)
6. **API Testing**: Implement comprehensive API testing
7. **Documentation**: Keep API documentation updated
