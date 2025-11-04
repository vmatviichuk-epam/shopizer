# Default Credentials

This document contains the default credentials for accessing the Shopizer backend and example API calls to test authentication.

## Admin Credentials

The system creates one default admin user during initialization:

- **Email:** `admin@shopizer.com`
- **Password:** `password`

## Login Endpoints

### Admin Login

**Endpoint:** `POST /api/v1/private/login`

**URL:** `http://localhost:8080/api/v1/private/login`

**Request Body:**
```json
{
  "username": "admin@shopizer.com",
  "password": "password"
}
```

**cURL Example:**
```bash
curl -X POST "http://localhost:8080/api/v1/private/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin@shopizer.com",
    "password": "password"
  }'
```

**Expected Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "username": "admin@shopizer.com"
}
```

The `token` field contains a JWT token that should be used in subsequent API calls.

## Using the JWT Token

Once you receive the JWT token, include it in the `Authorization` header for authenticated requests:

```bash
curl -X GET "http://localhost:8080/api/v1/private/merchants" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9..."
```

## Customer Accounts

**Note:** The system does not create any default customer accounts. Customer accounts must be registered through the registration endpoint:

**Endpoint:** `POST /api/v1/customer/register`

**URL:** `http://localhost:8080/api/v1/customer/register`

## API Documentation

For complete API documentation, visit the Swagger UI:

**URL:** http://localhost:8080/swagger-ui.html

## Security Notes

**IMPORTANT:**
- These are default credentials for local development only
- Change the admin password immediately in production environments
- Never commit production credentials to version control
- Use environment variables or secure credential management for production deployments
