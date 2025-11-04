# Shopizer Login & Authentication Process Documentation

## Overview

Shopizer implements a JWT (JSON Web Token) based authentication system with separate authentication flows for:
- **Admin Users**: Backend administrators with role-based permissions
- **Customers**: Frontend shop customers with order and account management capabilities

The authentication system uses Spring Security with custom JWT token management, providing stateless authentication for REST API endpoints. **Enhanced password policy enforcement** includes complexity requirements, password history tracking, periodic renewal (6-month expiration), and mandatory password change flows for policy violations.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Authentication Flows](#authentication-flows)
3. [API Endpoints](#api-endpoints)
4. [Security Configuration](#security-configuration)
5. [JWT Token Management](#jwt-token-management)
6. [Request/Response Models](#requestresponse-models)
7. [Configuration Properties](#configuration-properties)
8. [Implementation Details](#implementation-details)
9. [Error Handling](#error-handling)
10. [Security Considerations](#security-considerations)

---

## Architecture Overview



**Updated Architecture Diagram**: The following diagram shows the complete authentication flow for both Admin and Customer login processes.

```mermaid
graph TD
    A[Client Application] -->|POST /api/v1/private/login| B[AuthenticateUserApi]
    A -->|POST /api/v1/customer/login| C[AuthenticateCustomerApi]

    B --> D[jwtAdminAuthenticationManager]
    C --> E[jwtCustomerAuthenticationManager]

    D --> F[JWTAdminAuthenticationProvider]
    E --> G[JWTCustomerAuthenticationProvider]

    F --> H[JWTAdminServicesImpl]
    G --> I[JWTCustomerServicesImpl]

    H --> J[UserService]
    I --> K[CustomerService]

    J --> L[(User Database)]
    K --> M[(Customer Database)]

    H --> N[PermissionService/GroupService]
    I --> N

    N --> O[(Permissions Database)]

    H --> P[JWTUser]
    I --> P

    P --> Q[JWTTokenUtil]
    Q --> R[Generate JWT Token]

    R --> S[AuthenticationResponse]
    S --> A

    A -->|Subsequent Requests with Bearer Token| T[AuthenticationTokenFilter]
    T -->|/api/v*/private/**| U[jwtCustomAdminAuthenticationManager]
    T -->|/api/v*/auth/**| V[jwtCustomCustomerAuthenticationManager]

    U --> W[Validate Token]
    V --> W

    W --> X[SecurityContext]
    X --> Y[Protected Resource]

    %% Password policy components
    K --> PP[PasswordPolicyService]
    PP --> PH[(Password History DB)]
    PP --> PV[PasswordValidator]

    C --> PC[PasswordChangeController]
    PC --> PP

```



### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| **AuthenticateUserApi** | `sm-shop/store/api/v1/user/` | Admin login endpoint |
| **AuthenticateCustomerApi** | `sm-shop/store/api/v1/customer/` | Customer login/registration endpoints |
| **JWTTokenUtil** | `sm-shop/store/security/` | JWT token generation and validation |
| **AuthenticationTokenFilter** | `sm-shop/store/security/` | Filter for validating JWT tokens in requests |
| **MultipleEntryPointsSecurityConfig** | `sm-shop/application/config/` | Spring Security configuration |
| **JWTAdminServicesImpl** | `sm-shop/store/security/admin/` | User details service for admin users |
| **JWTCustomerServicesImpl** | `sm-shop/store/security/customer/` | User details service for customers |
| **PasswordPolicyService** | `sm-core/business/services/user/` | Password policy enforcement and history management |
| **PasswordValidator** | `sm-shop/validation/` | Real-time password complexity validation |
| **PasswordChangeController** | `sm-shop/store/api/v1/user/` | Mandatory password change endpoint |

---

## Authentication Flows

### Admin User Login Flow



**Updated Flow**: Step-by-step authentication process for admin users.

```mermaid
sequenceDiagram
    participant Client
    participant AuthAPI as AuthenticateUserApi
    participant AuthMgr as AuthenticationManager
    participant AuthProvider as JWTAdminAuthenticationProvider
    participant UserService as JWTAdminServicesImpl
    participant DB as Database
    participant PermSvc as PermissionService
    participant TokenUtil as JWTTokenUtil

    Client->>AuthAPI: POST /api/v1/private/login<br/>{username, password}

    AuthAPI->>AuthMgr: authenticate(username, password)
    AuthMgr->>AuthProvider: authenticate()

    AuthProvider->>UserService: loadUserByUsername(username)
    UserService->>DB: userService.getByUserName(username)
    DB-->>UserService: User entity

    alt User not found
        UserService-->>AuthProvider: UsernameNotFoundException
        AuthProvider-->>AuthAPI: AuthenticationException
        AuthAPI-->>Client: 401 Unauthorized
    end

    UserService->>DB: Get user groups
    DB-->>UserService: List<Group>

    UserService->>PermSvc: getPermissions(groupIds)
    PermSvc->>DB: Query permissions
    DB-->>PermSvc: List<Permission>
    PermSvc-->>UserService: Permissions

    UserService->>UserService: Build GrantedAuthorities
    UserService->>UserService: Create JWTUser with authorities
    UserService-->>AuthProvider: JWTUser (UserDetails)

    AuthProvider->>AuthProvider: Validate password (BCrypt)

    alt Invalid password
        AuthProvider-->>AuthAPI: BadCredentialsException
        AuthAPI-->>Client: 401 {"message":"Bad credentials"}
    end

    AuthProvider->>DB: Check last_password_update
    DB-->>AuthProvider: lastPasswordUpdate date

    alt Legacy User (lastPasswordUpdate == null)
        Note over AuthProvider: Skip expiration check<br/>Allow login
    else Password Expired (>6 months)
        AuthProvider-->>AuthAPI: PasswordExpiredException
        AuthAPI-->>Client: 403 {"requiresPasswordChange": true}
    else Password Doesn't Meet Policy
        AuthProvider->>DB: Check password complexity
        alt Complexity Check Fails
            AuthProvider-->>AuthAPI: PasswordPolicyException
            AuthAPI-->>Client: 403 {"requiresPasswordChange": true}
        end
    end

    AuthProvider-->>AuthMgr: Authentication object
    AuthMgr-->>AuthAPI: Authentication successful

    AuthAPI->>AuthAPI: Set SecurityContext
    AuthAPI->>UserService: Reload user details
    UserService-->>AuthAPI: JWTUser

    AuthAPI->>TokenUtil: generateToken(userDetails)
    TokenUtil->>TokenUtil: Build JWT claims
    TokenUtil->>TokenUtil: Sign with HS512 + secret
    TokenUtil-->>AuthAPI: JWT token string

    AuthAPI->>AuthAPI: Create AuthenticationResponse
    AuthAPI-->>Client: 200 OK<br/>{id, token}
```



**Steps:**

1. **Request**: Client sends POST to `/api/v1/private/login` with username and password
2. **Authentication**: `jwtAdminAuthenticationManager` authenticates credentials
3. **User Lookup**: `JWTAdminServicesImpl.loadUserByUsername()` retrieves user from database
4. **Permission Loading**: Loads user groups and associated permissions
5. **Authority Mapping**: Converts permissions to Spring Security `GrantedAuthority` objects
6. **Password Validation**: BCrypt password encoder validates credentials

7. **Password Policy Check**:
   - Check if user is legacy user (`last_password_update` is null) - if yes, skip expiration check
   - Check if password is expired (>6 months since last update)
   - Check if password meets complexity requirements (for non-legacy users)
   - If violations found, return 403 with `requiresPasswordChange: true`

8. **JWT Generation**: `JWTTokenUtil.generateToken()` creates signed JWT token
9. **Response**: Returns `AuthenticationResponse` with user ID and JWT token

**Key Code Reference:**
- Controller: `AuthenticateUserApi.java:66-104`
- Authentication Manager: `JWTAdminAuthenticationManager.java:36-78`
- User Service: `JWTAdminServicesImpl.java:72-112`

---

### Customer Login Flow



**Updated Flow**: Customer authentication process including registration.

```mermaid
sequenceDiagram
    participant Client
    participant AuthAPI as AuthenticateCustomerApi
    participant AuthMgr as AuthenticationManager
    participant CustomerSvc as JWTCustomerServicesImpl
    participant DB as Database
    participant PermSvc as PermissionService
    participant TokenUtil as JWTTokenUtil

    Client->>AuthAPI: POST /api/v1/customer/login<br/>{username, password}

    AuthAPI->>AuthMgr: authenticate(username, password)
    AuthMgr->>CustomerSvc: loadUserByUsername(username)

    CustomerSvc->>DB: customerService.getByNick(username)
    DB-->>CustomerSvc: Customer entity

    alt Customer not found
        CustomerSvc-->>AuthMgr: UsernameNotFoundException
        AuthMgr-->>AuthAPI: BadCredentialsException
        AuthAPI-->>Client: 401 {"message":"Bad credentials"}
    end

    CustomerSvc->>DB: Get customer groups
    DB-->>CustomerSvc: List<Group>

    CustomerSvc->>PermSvc: getPermissions(groupIds)
    PermSvc-->>CustomerSvc: List<Permission>

    CustomerSvc->>CustomerSvc: Add ROLE_AUTH_CUSTOMER
    CustomerSvc->>CustomerSvc: Build authorities
    CustomerSvc->>CustomerSvc: Create JWTUser
    CustomerSvc-->>AuthMgr: JWTUser

    AuthMgr->>AuthMgr: Validate password

    alt Password invalid
        AuthMgr-->>AuthAPI: BadCredentialsException
        AuthAPI-->>Client: 401 Unauthorized
    end

    AuthMgr->>DB: Check last_password_update
    DB-->>AuthMgr: lastPasswordUpdate date

    alt Legacy User (lastPasswordUpdate == null)
        Note over AuthMgr: Skip expiration check<br/>Allow login
    else Password Expired (>6 months)
        AuthMgr-->>AuthAPI: PasswordExpiredException
        AuthAPI-->>Client: 403 {"requiresPasswordChange": true, "reason": "expired"}
    end

    AuthMgr-->>AuthAPI: Authentication successful

    AuthAPI->>AuthAPI: Set SecurityContext
    AuthAPI->>CustomerSvc: Reload customer details
    CustomerSvc-->>AuthAPI: JWTUser

    AuthAPI->>TokenUtil: generateToken(userDetails)
    TokenUtil-->>AuthAPI: JWT token

    AuthAPI-->>Client: 200 OK<br/>{id, token}
```



**Steps:**

1. **Request**: Client sends POST to `/api/v1/customer/login` with username and password
2. **Authentication**: `jwtCustomerAuthenticationManager` authenticates credentials
3. **Customer Lookup**: `JWTCustomerServicesImpl.loadUserByUsername()` retrieves customer by nickname
4. **Permission Loading**: Loads customer groups and permissions
5. **Authority Mapping**: Adds `ROLE_AUTH_CUSTOMER` and permission-based authorities
6. **Password Validation**: BCrypt password encoder validates credentials

7. **Password Policy Check**:
   - Check if customer is legacy user (`last_password_update` is null) - if yes, skip expiration check
   - Check if password is expired (>6 months since last update) for non-legacy users
   - If expired, return 403 with `requiresPasswordChange: true` and `reason: "expired"`

8. **JWT Generation**: `JWTTokenUtil.generateToken()` creates signed JWT token
9. **Response**: Returns `AuthenticationResponse` with customer ID and JWT token

**Key Code Reference:**
- Controller: `AuthenticateCustomerApi.java:157-196`
- User Service: `AbstractCustomerServices.java:50-94`
- JWT User Factory: `JWTCustomerServicesImpl.java:34-54`

---

### Password Policy Enforcement Flow

This diagram illustrates the complete password policy enforcement flow, including mandatory password change for expired or non-compliant passwords.

```mermaid
sequenceDiagram
    participant Client
    participant LoginAPI as Login API
    participant PolicySvc as PasswordPolicyService
    participant DB as Database
    participant ChangeAPI as Password Change API
    participant Validator as PasswordValidator
    participant HistorySvc as PasswordHistoryService

    Client->>LoginAPI: Login with credentials
    LoginAPI->>PolicySvc: checkPasswordPolicy(user)
    PolicySvc->>DB: Get last_password_update
    DB-->>PolicySvc: lastPasswordUpdate

    alt Legacy User (lastPasswordUpdate == null)
        PolicySvc-->>LoginAPI: Policy check passed
        LoginAPI-->>Client: 200 OK + Token
    else Password Expired
        PolicySvc-->>LoginAPI: PasswordExpiredException
        LoginAPI-->>Client: 403 {"requiresPasswordChange": true}

        Client->>ChangeAPI: GET /mandatory-password-change
        ChangeAPI-->>Client: Mandatory change form

        Client->>ChangeAPI: POST new password
        ChangeAPI->>Validator: validatePassword(newPassword)

        alt Validation Failed
            Validator-->>ChangeAPI: Validation errors
            ChangeAPI-->>Client: 400 + Error details
        end

        ChangeAPI->>HistorySvc: checkPasswordHistory(user, newPassword)
        HistorySvc->>DB: Get last 5 password hashes
        DB-->>HistorySvc: Password history

        alt Password in history
            HistorySvc-->>ChangeAPI: Password reused
            ChangeAPI-->>Client: 400 "Cannot reuse last 5 passwords"
        end

        ChangeAPI->>DB: Update password
        ChangeAPI->>DB: Set last_password_update = now()
        ChangeAPI->>DB: Set password_expiration = now() + 6 months
        ChangeAPI->>HistorySvc: addToHistory(user, passwordHash)
        HistorySvc->>DB: Insert password history
        HistorySvc->>DB: Keep only last 5 entries

        ChangeAPI->>ChangeAPI: Log password change event
        ChangeAPI->>ChangeAPI: Send confirmation notification
        ChangeAPI-->>Client: 200 OK

        Client->>LoginAPI: Re-login with new password
        LoginAPI-->>Client: 200 OK + Token
    end
```

**Key Features:**

1. **Legacy User Support**: Users with `last_password_update = null` skip expiration checks
2. **6-Month Expiration**: Enforced for all users who have changed password at least once
3. **Password History**: Prevents reuse of last 5 passwords
4. **Real-time Validation**: Client-side and server-side password complexity checks
5. **Audit Logging**: All password changes are logged with timestamp and user ID
6. **Notifications**: Users receive confirmation after successful password change

---

### Customer Registration Flow



Self-service customer registration with automatic authentication.

```mermaid
sequenceDiagram
    participant Client
    participant AuthAPI as AuthenticateCustomerApi
    participant CustomerFacade
    participant CustomerSvc as CustomerService
    participant DB as Database
    participant AuthMgr as AuthenticationManager
    participant TokenUtil as JWTTokenUtil

    Client->>AuthAPI: POST /api/v1/customer/register<br/>PersistableCustomer

    AuthAPI->>CustomerFacade: checkIfUserExists(email, store)
    CustomerFacade->>DB: Query by email
    DB-->>CustomerFacade: Exists/Not exists

    alt User already exists
        CustomerFacade-->>AuthAPI: true
        AuthAPI-->>Client: 409 Conflict<br/>"Customer already registered"
    end

    AuthAPI->>AuthAPI: Validate password complexity
    alt Password validation fails
        AuthAPI-->>Client: 400 Bad Request + Validation errors
    end

    AuthAPI->>AuthAPI: Validate customer data

    alt Validation fails
        AuthAPI-->>Client: 400 Bad Request
    end

    AuthAPI->>CustomerFacade: registerCustomer(customer, store, lang)
    CustomerFacade->>CustomerSvc: Save customer
    CustomerSvc->>CustomerSvc: Hash password (BCrypt)

    CustomerSvc->>DB: Set last_password_update = null (for legacy support)
    CustomerSvc->>DB: Initialize empty password_history

    CustomerSvc->>DB: Insert customer record
    DB-->>CustomerSvc: Customer entity
    CustomerSvc-->>CustomerFacade: Saved customer
    CustomerFacade-->>AuthAPI: Registration complete

    AuthAPI->>AuthMgr: authenticate(username, password)
    Note over AuthAPI,AuthMgr: Auto-login after registration

    AuthMgr-->>AuthAPI: Authentication successful

    AuthAPI->>TokenUtil: generateToken(userDetails)
    TokenUtil-->>AuthAPI: JWT token

    AuthAPI-->>Client: 201 Created<br/>{id, token}
```



**Steps:**

1. **Request**: Client sends POST to `/api/v1/customer/register` with customer details
2. **Validation**: Check if user already exists by email


3. **Password Complexity Validation**: Validate password meets all complexity requirements before registration


4. **Registration**: `customerFacade.registerCustomer()` creates new customer account
5. **Password Hashing**: Password is hashed using BCrypt before storage


6. **Initialize Password Tracking**:
   - Set `last_password_update = null` to mark as legacy user (exempted from expiration)
   - Initialize empty password history
   - User will be subject to full policy enforcement only after their first password change


7. **Auto-Login**: Automatically authenticate the newly registered customer
8. **JWT Generation**: Generate JWT token for immediate access
9. **Response**: Returns `AuthenticationResponse` with HTTP 201 Created

**Key Code Reference:**
- Controller: `AuthenticateCustomerApi.java:94-148`

---

## API Endpoints

### Admin Authentication Endpoints



**Updated Endpoints**: Enhanced with security details and examples.

#### POST `/api/v1/private/login`

Authenticates an admin user and returns a JWT token.

**Request:**
```json
{
  "username": "admin@example.com",
  "password": "SecurePassword123"
}
```

**Response (200 OK):**
```json
{
  "id": 1,
  "token": "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJhZG1pbkBleGFtcGxlLmNvbSIsImF1ZCI6ImFwaSIsImlhdCI6MTYzMjQyNzIwMCwiZXhwIjoxNjMyNDMwODAwfQ.signature"
}
```

**Error Responses:**
- `401 Unauthorized`: Invalid credentials
  ```json
  {"message": "Bad credentials"}
  ```
- `404 Not Found`: User not found or authentication failed


- `403 Forbidden`: Password change required
  ```json
  {
    "requiresPasswordChange": true,
    "reason": "expired",
    "message": "Your password has expired. Please change your password."
  }
  ```
  or
  ```json
  {
    "requiresPasswordChange": true,
    "reason": "policy_violation",
    "message": "Your password does not meet current security requirements."
  }
  ```


**Security:**
- URL Pattern: `/api/v*/private/login*` (permitAll)
- No authentication required for this endpoint
- Rate limiting recommended (not implemented by default)

**Code Reference:** `AuthenticateUserApi.java:66`

---

#### GET `/api/v1/auth/refresh`

Refreshes an existing JWT token if it's still valid.

**Request Headers:**
```
Authorization: Bearer <existing-jwt-token>
```

**Response (200 OK):**
```json
{
  "id": 1,
  "token": "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJhZG1pbkBleGFtcGxlLmNvbSIsImF1ZCI6ImFwaSIsImlhdCI6MTYzMjQzMDgwMCwiZXhwIjoxNjMyNDM0NDAwfQ.signature"
}
```

**Error Responses:**
- `400 Bad Request`: Token cannot be refreshed (expired beyond grace period)

**Security:**
- URL Pattern: `/api/v*/private/refresh` (permitAll)
- Validates token before refreshing
- Grace period: 200 seconds (configurable)

**Code Reference:** `AuthenticateUserApi.java:107`



---


### Password Change Endpoints

#### GET `/api/v1/auth/mandatory-password-change`

Displays the mandatory password change interface when policy violations are detected.

**Request Headers:**
```
Authorization: Bearer <existing-jwt-token>
```

**Response (200 OK):**
Returns HTML form or redirects to password change UI

**UI Requirements:**
- New Password field (password input with show/hide toggle)
- Repeat New Password field (password input with show/hide toggle)
- Next button (enabled only when both fields are valid and match)
- Logout button (positioned to the left of Next button)
- Password requirements tooltip (always visible or accessible via info icon)

**Password Requirements Tooltip:**
```
Password Requirements:
✓ At least 8 characters long
✓ Contains at least 1 lowercase letter (a-z)
✓ Contains at least 1 uppercase letter (A-Z)
✓ Contains at least 1 number (0-9)
✓ Contains at least 1 special character (!@#$%^&*()_+-=[]{}|;:,.<>?)
✓ Cannot be one of your last 5 passwords
```

**Security:**
- URL Pattern: `/api/v*/auth/mandatory-password-change` (authenticated users only)
- Users cannot access other functionality until password is changed
- Session remains active to allow password change

---

#### POST `/api/v1/auth/change-password`

Changes a user's password with policy enforcement.

**Request:**
```json
{
  "username": "user@example.com",
  "newPassword": "NewSecurePass123!",
  "repeatPassword": "NewSecurePass123!"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Password changed successfully"
}
```

**Error Responses:**

- `400 Bad Request`: Password doesn't meet complexity requirements
  ```json
  {
    "errors": [
      {
        "field": "password",
        "message": "Password must contain at least one uppercase letter"
      }
    ]
  }
  ```

- `400 Bad Request`: Password in history
  ```json
  {
    "error": "password_reused",
    "message": "You cannot reuse any of your last 5 passwords"
  }
  ```

- `400 Bad Request`: Passwords don't match
  ```json
  {
    "error": "password_mismatch",
    "message": "New password and repeat password do not match"
  }
  ```

**Security:**
- Requires authentication
- Validates password complexity in real-time
- Checks against password history (last 5 passwords)
- Updates `last_password_update` timestamp
- Sets `password_expiration` to 6 months from change date
- Adds password hash to password history (maintaining only last 5)
- Logs password change event
- Sends confirmation notification to user

**Code Reference:** `PasswordChangeController.java` *(to be implemented)*


---

### Customer Authentication Endpoints



**Updated Endpoints**: Complete customer authentication API documentation.

#### POST `/api/v1/customer/login`

Authenticates a customer and returns a JWT token.

**Request:**
```json
{
  "username": "customer@example.com",
  "password": "CustomerPassword123"
}
```

**Response (200 OK):**
```json
{
  "id": 100,
  "token": "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJjdXN0b21lckBleGFtcGxlLmNvbSIsImF1ZCI6ImFwaSIsImlhdCI6MTYzMjQyNzIwMCwiZXhwIjoxNjMyNDMwODAwfQ.signature"
}
```

**Error Responses:**
- `401 Unauthorized`: Invalid credentials
  ```json
  {"message": "Bad credentials"}
  ```


- `403 Forbidden`: Password change required
  ```json
  {
    "requiresPasswordChange": true,
    "reason": "expired",
    "message": "Your password has expired. Please change your password to continue."
  }
  ```


- `500 Internal Server Error`: System error during authentication

**Security:**
- URL Pattern: `/api/v*/customer/login` (mapped to customer authentication realm)
- Username is typically the customer's email address
- Password validation uses BCrypt


- Password expiration checked for non-legacy users (where `last_password_update` is not null)


**Code Reference:** `AuthenticateCustomerApi.java:157`

---

#### POST `/api/v1/customer/register`

Registers a new customer and automatically authenticates them.

**Request:**
```json
{
  "emailAddress": "newcustomer@example.com",
  "password": "SecurePass123",
  "billing": {
    "firstName": "John",
    "lastName": "Doe",
    "country": "US",
    "address": "123 Main St",
    "city": "New York",
    "postalCode": "10001"
  }
}
```

**Response (201 Created):**
```json
{
  "id": 101,
  "token": "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJuZXdjdXN0b21lckBleGFtcGxlLmNvbSIsImF1ZCI6ImFwaSIsImlhdCI6MTYzMjQyNzIwMCwiZXhwIjoxNjMyNDMwODAwfQ.signature"
}
```

**Error Responses:**
- `409 Conflict`: Customer already exists
  ```json
  "Customer with email [newcustomer@example.com] is already registered"
  ```


- `400 Bad Request`: Password validation errors *(Enhanced)*
  ```json
  {
    "errors": [
      {
        "field": "password",
        "code": "INSUFFICIENT_UPPERCASE",
        "message": "Password must contain at least 1 uppercase character"
      },
      {
        "field": "password",
        "code": "INSUFFICIENT_DIGIT",
        "message": "Password must contain at least 1 digit"
      }
    ]
  }
  ```


- `400 Bad Request`: Validation errors (missing required fields)

**Validation Requirements:**
- `userName` (auto-set to emailAddress): Required
- `billing.country`: Required


- `password`: Required, must meet complexity requirements *(Enhanced)*:
  - Minimum 8 characters
  - At least 1 lowercase letter (a-z)
  - At least 1 uppercase letter (A-Z)
  - At least 1 number (0-9)
  - At least 1 special character (!@#$%^&*()_+-=[]{}|;:,.<>?)


**Security:**
- URL Pattern: `/api/v*/auth/register` (permitAll)
- Automatically creates user with `ROLE_AUTH_CUSTOMER`
- Password is hashed before storage


- New users are created with `last_password_update = null` (legacy user status for backward compatibility)
- Full password policy enforcement applies only after first password change


**Code Reference:** `AuthenticateCustomerApi.java:94`

---

#### POST `/api/v1/auth/customer/password`

Changes a customer's password (requires current password verification).

**Request:**
```json
{
  "username": "customer@example.com",
  "current": "OldPassword123",
  "password": "NewPassword456",
  "repeatPassword": "NewPassword456"
}
```

**Response (200 OK):**
```
Void
```

**Error Responses:**
- `404 Not Found`: Customer not found
- `400 Bad Request`: Password mismatch or validation error


- `400 Bad Request`: Password in history
  ```json
  {
    "error": "password_reused",
    "message": "You cannot reuse any of your last 5 passwords"
  }
  ```

- `400 Bad Request`: Password complexity violation
  ```json
  {
    "errors": [
      {
        "field": "password",
        "message": "Password must contain at least one special character"
      }
    ]
  }
  ```


**Security:**
- Requires authentication
- Validates current password before allowing change
- New password must match repeat password


- Validates password complexity
- Checks password history (last 5 passwords)
- Updates `last_password_update` timestamp
- Sets `password_expiration` to 6 months from change
- Logs password change event
- Sends confirmation notification


**Code Reference:** `AuthenticateCustomerApi.java:215`

---

#### GET `/api/v1/auth/customer/refresh`

Refreshes a customer's JWT token.

**Request Headers:**
```
Authorization: Bearer <existing-jwt-token>
```

**Response (200 OK):**
```json
{
  "id": 100,
  "token": "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJjdXN0b21lckBleGFtcGxlLmNvbSIsImF1ZCI6ImFwaSIsImlhdCI6MTYzMjQzMDgwMCwiZXhwIjoxNjMyNDM0NDAwfQ.signature"
}
```

**Error Responses:**
- `400 Bad Request`: Token cannot be refreshed

**Security:**
- Validates token expiration and last password reset date
- Token audience must match

**Code Reference:** `AuthenticateCustomerApi.java:198`



---

## Security Configuration

### Spring Security Configuration



**Updated Configuration**: Multi-realm security setup with JWT token filters.

The security configuration is defined in `MultipleEntryPointsSecurityConfig.java` with multiple security adapters:

#### 1. Customer Shop Configuration (Order: 1)
```java
@Configuration
@Order(1)
public static class CustomerConfigurationAdapter extends WebSecurityConfigurerAdapter {
    // Handles /shop/** paths
    // Traditional session-based authentication for web shop
}
```

#### 2. Services API Configuration (Order: 2)
```java
@Configuration
@Order(2)
public static class ServicesApiConfigurationAdapter extends WebSecurityConfigurerAdapter {
    // Handles /services/** paths (deprecated v0 API)
    // Basic authentication with service realm
}
```

#### 3. User API Configuration (Order: 5)
```java
@Configuration
@Order(5)
public static class UserApiConfigurationAdapter extends WebSecurityConfigurerAdapter {

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
            .antMatcher("/api/v*/private/**")
            .authorizeRequests()
                .antMatchers("/api/v*/private/login*").permitAll()
                .antMatchers("/api/v*/private/refresh").permitAll()
                .antMatchers(HttpMethod.OPTIONS, "/api/v*/private/**").permitAll()
                .antMatchers("/api/v*/private/**").hasRole("AUTH")
            .and()
                .addFilterAfter(authenticationTokenFilter, BasicAuthenticationFilter.class)
                .csrf().disable();
    }

    @Bean
    public AuthenticationProvider authenticationProvider() {
        JWTAdminAuthenticationProvider provider = new JWTAdminAuthenticationProvider();
        provider.setUserDetailsService(jwtUserDetailsService);
        return provider;
    }
}
```

**Key Features:**
- JWT token filter processes requests after basic authentication filter
- Login and refresh endpoints are publicly accessible
- All other `/private/**` endpoints require `ROLE_AUTH` authority
- CSRF protection disabled (stateless JWT authentication)
- OPTIONS requests permitted for CORS preflight

#### 4. Customer API Configuration (Order: 6)
```java
@Configuration
@Order(6)
public static class CustomeApiConfigurationAdapter extends WebSecurityConfigurerAdapter {

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
            .antMatcher("/api/v*/auth/**")
            .authorizeRequests()
                .antMatchers("/api/v*/auth/refresh").permitAll()
                .antMatchers("/api/v*/auth/login").permitAll()
                .antMatchers("/api/v*/auth/register").permitAll()
                .antMatchers(HttpMethod.OPTIONS, "/api/v*/auth/**").permitAll()
                .antMatchers("/api/v*/auth/**").hasRole("AUTH_CUSTOMER")
            .and()
                .addFilterAfter(authenticationTokenFilter, BasicAuthenticationFilter.class)
                .csrf().disable();
    }

    @Bean
    public AuthenticationProvider authenticationProvider() {
        JWTCustomerAuthenticationProvider provider = new JWTCustomerAuthenticationProvider();
        provider.setUserDetailsService(jwtCustomerDetailsService);
        return provider;
    }
}
```

**Key Features:**
- Public access to login, register, and refresh endpoints
- Protected endpoints require `ROLE_AUTH_CUSTOMER` authority
- JWT token filter validates customer tokens
- CORS support with OPTIONS method


#### 5. Password Policy Configuration (Order: 4)

```java
@Configuration
@Order(4)
public static class PasswordPolicyConfigurationAdapter extends WebSecurityConfigurerAdapter {

    @Override
    protected void configure(HttpSecurity http) throws Exception {
        http
            .antMatcher("/api/v*/auth/**")
            .authorizeRequests()
                .antMatchers("/api/v*/auth/mandatory-password-change").authenticated()
                .antMatchers("/api/v*/auth/change-password").authenticated()
            .and()
                .addFilterAfter(passwordPolicyEnforcementFilter, AuthenticationTokenFilter.class)
                .csrf().disable();
    }

    @Bean
    public PasswordPolicyEnforcementFilter passwordPolicyEnforcementFilter() {
        return new PasswordPolicyEnforcementFilter(passwordPolicyService);
    }
}
```

**Key Features:**
- Password change endpoints require authentication
- Password policy enforcement filter checks expiration on protected resource access
- Redirects to mandatory password change when violations detected
- Allows logout even when password change is required


**Code Reference:** `MultipleEntryPointsSecurityConfig.java:285-424`



---

### Authentication Token Filter



**Updated Filter Logic**: How JWT tokens are validated on each request.

The `AuthenticationTokenFilter` intercepts requests and validates JWT tokens.

**Filter Logic:**

```java
@Override
protected void doFilterInternal(HttpServletRequest request,
                                 HttpServletResponse response,
                                 FilterChain chain) {

    // 1. Set CORS headers
    response.setHeader("Access-Control-Allow-Origin", origin);
    response.setHeader("Access-Control-Allow-Methods", "POST, GET, PUT, OPTIONS, DELETE, PATCH");
    // 3. Customer authentication (/api/v*/auth/**)
    if(requestUrl.contains("/api/v1/auth")) {
        if (requestHeader != null && requestHeader.startsWith("Bearer ")) {
            jwtCustomCustomerAuthenticationManager.authenticateRequest(request, response);
        }
    }

    // 4. Admin authentication (/api/v*/private/**)
    if(requestUrl.contains("/api/v1/private") || requestUrl.contains("/api/v2/private")) {
        if (requestHeader != null && requestHeader.startsWith("Bearer ")) {
            jwtCustomAdminAuthenticationManager.authenticateRequest(request, response);
        }
    }

    // 5. Continue filter chain
    chain.doFilter(request, response);

    // 6. Cleanup user context
    UserContext.getCurrentInstance().close();
}
```

**Token Validation Process:**

1. **Extract Token**: Extract JWT from `Authorization` header
2. **Parse Claims**: Decode JWT and extract username
3. **Load User**: Load user/customer details from database
4. **Validate Token**:
   - Verify signature using secret key
   - Check token expiration
   - Verify username matches
   - Confirm token created after last password reset
5. **Set Authentication**: If valid, set `SecurityContext` with authenticated user
6. **Reject Invalid**: If invalid, continue without authentication (endpoint will reject)

**Code Reference:**
- Filter: `AuthenticationTokenFilter.java:50-126`
- Admin Manager: `JWTAdminAuthenticationManager.java:36-78`



---


### Password Policy Enforcement Filter

The `PasswordPolicyEnforcementFilter` enforces password expiration and complexity requirements on every protected resource access.

**Filter Logic:**

```java
@Component
public class PasswordPolicyEnforcementFilter extends OncePerRequestFilter {

    @Inject
    private PasswordPolicyService passwordPolicyService;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                     HttpServletResponse response,
                                     FilterChain filterChain) throws ServletException, IOException {

        // Skip filter for public endpoints
        String requestUri = request.getRequestURI();
        if (isPublicEndpoint(requestUri)) {
            filterChain.doFilter(request, response);
            return;
        }

        // Get authenticated user
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !authentication.isAuthenticated()) {
            filterChain.doFilter(request, response);
            return;
        }

        JWTUser user = (JWTUser) authentication.getPrincipal();

        // Check password policy
        PasswordPolicyStatus status = passwordPolicyService.checkPolicy(user);

        if (status.isLegacyUser()) {
            // Legacy users (last_password_update == null) are exempt
            filterChain.doFilter(request, response);
            return;
        }

        if (status.isExpired()) {
            // Redirect to mandatory password change
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            response.setContentType("application/json");
            response.getWriter().write("{\"requiresPasswordChange\": true, \"reason\": \"expired\"}");
            return;
        }

        if (status.violatesComplexity()) {
            // Redirect to mandatory password change
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            response.setContentType("application/json");
            response.getWriter().write("{\"requiresPasswordChange\": true, \"reason\": \"policy_violation\"}");
            return;
        }

        // Password policy satisfied, continue
        filterChain.doFilter(request, response);
    }

    private boolean isPublicEndpoint(String uri) {
        return uri.contains("/login") ||
               uri.contains("/register") ||
               uri.contains("/mandatory-password-change") ||
               uri.contains("/change-password") ||
               uri.contains("/logout");
    }
}
```

**Policy Check Process:**

1. **Skip Public Endpoints**: Login, register, and password change endpoints bypass the filter
2. **Get Authenticated User**: Extract user from SecurityContext
3. **Check Legacy Status**: Users with `last_password_update = null` skip all policy checks
4. **Check Expiration**: Verify password is not older than 6 months
5. **Check Complexity**: For non-legacy users, verify password meets current complexity requirements
6. **Enforce or Allow**: Redirect to mandatory password change or allow access

**Code Reference:** `PasswordPolicyEnforcementFilter.java` *(to be implemented)*


---

## JWT Token Management

### Token Generation



**Updated Token Structure**: JWT token format and claims.

**Token Generation Process:**

```java
public String generateToken(UserDetails userDetails) {
    Map<String, Object> claims = new HashMap<>();
    return doGenerateToken(claims, userDetails.getUsername(), generateAudience());
}

private String doGenerateToken(Map<String, Object> claims, String subject, String audience) {
public String generateToken(UserDetails userDetails) {
    Map<String, Object> claims = new HashMap<>();
    return doGenerateToken(claims, userDetails.getUsername(), generateAudience());
}

private String doGenerateToken(Map<String, Object> claims, String subject, String audience) {
    final Date createdDate = DateUtil.getDate();
    final Date expirationDate = calculateExpirationDate(createdDate);

    return Jwts.builder()
        .setClaims(claims)
        .setSubject(subject)              // Username
        .setAudience(audience)            // "api"
        .setIssuedAt(createdDate)         // Current timestamp
        .setExpiration(expirationDate)    // createdDate + expiration
        .signWith(SignatureAlgorithm.HS512, secret)  // HMAC SHA-512
        .compact();
}
```

**JWT Token Structure:**

```json
{
  "header": {
    "alg": "HS512",
    "typ": "JWT"
  },
  "payload": {
    "sub": "admin@example.com",
    "aud": "api",
    "iat": 1632427200,
    "exp": 1632430800
  },
  "signature": "HMACSHA512(base64UrlEncode(header) + '.' + base64UrlEncode(payload), secret)"
}
```

**Claims:**
- `sub` (subject): Username/email address
- `aud` (audience): Token audience ("api", "web", "mobile", "tablet")
- `iat` (issued at): Token creation timestamp
- `exp` (expiration): Token expiration timestamp

**Configuration:**
- Algorithm: HS512 (HMAC with SHA-512)
- Secret: Configured via `${jwt.secret}` property
- Expiration: Configured via `${jwt.expiration}` property (in seconds)

**Code Reference:** `JWTTokenUtil.java:119-138`



---

### Token Validation



**Updated Validation Logic**: Complete token verification process.

**Validation Criteria:**

```java
public Boolean validateToken(String token, UserDetails userDetails) {
    JWTUser user = (JWTUser) userDetails;
    final String username = getUsernameFromToken(token);
    final Date created = getIssuedAtDateFromToken(token);

    boolean usernameEquals = username.equals(user.getUsername());
    boolean isTokenExpired = isTokenExpired(token);
    boolean isTokenCreatedBeforeLastPasswordReset =
        isCreatedBeforeLastPasswordReset(created, user.getLastPasswordResetDate());

    return (usernameEquals &&
            !isTokenExpired &&
            !isTokenCreatedBeforeLastPasswordReset);
}
```

**Validation Steps:**

1. **Parse Token**: Extract claims using secret key
   ```java
   Claims claims = Jwts.parser()
       .setSigningKey(secret)
       .parseClaimsJws(token)
       .getBody();
   ```

2. **Verify Username**: Token subject matches user
3. **Check Expiration**: Current time < expiration time
4. **Verify Password Reset**: Token created after last password change
5. **Signature Validation**: Automatically validated by JJWT library

**Token Expiration:**
```java
private Boolean isTokenExpired(String token) {
    final Date expiration = getExpirationDateFromToken(token);
    return expiration.before(DateUtil.getDate());
}
```

**Password Reset Check:**
```java
private Boolean isCreatedBeforeLastPasswordReset(Date created, Date lastPasswordReset) {
    return (lastPasswordReset != null && created.before(lastPasswordReset));
}
```

**Code Reference:** `JWTTokenUtil.java:173-187`



---

### Token Refresh



Token refresh with grace period support.

**Refresh Logic:**

```java
public Boolean canTokenBeRefreshed(String token, Date lastPasswordReset) {
    final Date created = getIssuedAtDateFromToken(token);
    return !isCreatedBeforeLastPasswordReset(created, lastPasswordReset)
            && (!isTokenExpired(token) || ignoreTokenExpiration(token));
}

public String refreshToken(String token) {
    final Date createdDate = DateUtil.getDate();
    final Date expirationDate = calculateExpirationDate(createdDate);

    final Claims claims = getAllClaimsFromToken(token);
    claims.setIssuedAt(createdDate);
    claims.setExpiration(expirationDate);

    return Jwts.builder()
        .setClaims(claims)
        .signWith(SignatureAlgorithm.HS512, secret)
        .compact();
}
```

**Refresh Conditions:**

1. Token not created before last password reset
2. Token not expired OR audience allows ignoring expiration
3. Grace period: 200 seconds (for mobile/tablet audiences)

**Audiences Supporting Grace Period:**
- `tablet`: Token expiration can be ignored
- `mobile`: Token expiration can be ignored
- `api`, `web`: Strict expiration enforcement

**Grace Period Logic:**
```java
private Boolean canTokenBeRefreshedWithGrace(String token, Date lastPasswordReset) {
    final Date created = getIssuedAtDateFromToken(token);
    return !isCreatedBeforeLastPasswordResetWithGrace(created, lastPasswordReset)
            && (!isTokenExpiredWithGrace(token) || ignoreTokenExpiration(token));
}

private Boolean isTokenExpiredWithGrace(String token) {
    Date expiration = getExpirationDateFromToken(token);
    expiration = addSeconds(expiration, GRACE_PERIOD); // 200 seconds
    return expiration.before(DateUtil.getDate());
}
```

**Code Reference:** `JWTTokenUtil.java:140-171`



---

## Request/Response Models

### AuthenticationRequest



**Login Request Model**: Used for both admin and customer authentication.

```java
public class AuthenticationRequest implements Serializable {

    @NotEmpty(message="{NotEmpty.customer.userName}")
    private String username;

    @NotEmpty(message="{message.password.required}")
    private String password;

    // Constructors, getters, setters...
}
```

**Validation:**
- `username`: Required, cannot be empty
- `password`: Required, cannot be empty

**Example:**
```json
{
  "username": "user@example.com",
  "password": "SecurePassword123"
}
```

**Code Reference:** `AuthenticationRequest.java:7-51`



---

### AuthenticationResponse



**Login Response Model**: Contains user ID and JWT token.

```java
public class AuthenticationResponse extends Entity implements Serializable {

    private String token;

    public AuthenticationResponse(Long userId, String token) {
        this.token = token;
        super.setId(userId);
    }

    // Getters...
}
```

**Fields:**
- `id`: User/Customer ID (inherited from Entity)
- `token`: JWT token string

**Example:**
```json
{
  "id": 1,
  "token": "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJhZG1pbkBleGFtcGxlLmNvbSIsImF1ZCI6ImFwaSIsImlhdCI6MTYzMjQyNzIwMCwiZXhwIjoxNjMyNDMwODAwfQ.signature"
}
```

**Code Reference:** `AuthenticationResponse.java:6-24`



---


### PasswordChangeRequest

**Password Change Request Model**: Used for mandatory and voluntary password changes.

```java
public class PasswordChangeRequest implements Serializable {

    @NotEmpty(message="Username is required")
    private String username;

    @NotEmpty(message="New password is required")
    @PasswordComplexity
    private String newPassword;

    @NotEmpty(message="Repeat password is required")
    private String repeatPassword;

    private String currentPassword; // Optional, required for voluntary changes

    // Constructors, getters, setters...
}
```

**Validation:**
- `username`: Required
- `newPassword`: Required, must meet complexity requirements
- `repeatPassword`: Required, must match newPassword
- `currentPassword`: Required for voluntary password changes, not required for mandatory changes

**Password Complexity Validation (@PasswordComplexity):**
- Minimum 8 characters
- At least 1 lowercase letter (a-z)
- At least 1 uppercase letter (A-Z)
- At least 1 number (0-9)
- At least 1 special character (!@#$%^&*()_+-=[]{}|;:,.<>?)

**Example:**
```json
{
  "username": "user@example.com",
  "newPassword": "NewSecure123!",
  "repeatPassword": "NewSecure123!",
  "currentPassword": "OldPassword123"
}
```

**Code Reference:** `PasswordChangeRequest.java` *(to be implemented)*


---


### PasswordPolicyStatus

**Password Policy Status Model**: Contains password policy validation results.

```java
public class PasswordPolicyStatus {

    private boolean isLegacyUser;
    private boolean isExpired;
    private boolean violatesComplexity;
    private Date lastPasswordUpdate;
    private Date passwordExpiration;
    private List<String> complexityViolations;

    // Constructors, getters, setters...
}
```

**Fields:**
- `isLegacyUser`: True if `last_password_update` is null (exempt from expiration)
- `isExpired`: True if password is older than 6 months
- `violatesComplexity`: True if password doesn't meet current complexity requirements
- `lastPasswordUpdate`: Timestamp of last password change
- `passwordExpiration`: Calculated expiration date (lastPasswordUpdate + 6 months)
- `complexityViolations`: List of specific complexity requirements not met

**Example:**
```json
{
  "isLegacyUser": false,
  "isExpired": true,
  "violatesComplexity": false,
  "lastPasswordUpdate": "2023-03-15T10:30:00Z",
  "passwordExpiration": "2023-09-15T10:30:00Z",
  "complexityViolations": []
}
```

**Code Reference:** `PasswordPolicyStatus.java` *(to be implemented)*


---

### PersistableCustomer



**Customer Registration Model**: Used for creating new customer accounts.

```java
public class PersistableCustomer {

    @NotEmpty(message="Email is required")
    private String emailAddress;

    @NotEmpty(message="Password is required")
    private String password;

    private String userName; // Auto-set to emailAddress

    @Valid
    @NotNull(message="Billing address is required")
    private Address billing;

    // Other fields: firstName, lastName, company, phone, etc.
}

public class Address {
    @NotNull(message="Country is required")
    private String country;

    private String firstName;
    private String lastName;
    private String address;
    private String city;
    private String postalCode;
    private String stateProvince;
    private String zone;
}
```

**Required Fields:**
- `emailAddress`: Customer email
- `password`: Account password
- `billing.country`: Country code (e.g., "US", "CA")

**Optional Fields:**
- `billing.firstName`, `billing.lastName`
- `billing.address`, `billing.city`, `billing.postalCode`
- `company`, `phone`

**Example:**
```json
{
  "emailAddress": "customer@example.com",
  "password": "SecurePass123",
  "billing": {
    "firstName": "John",
    "lastName": "Doe",
    "country": "US",
    "address": "123 Main St",
    "city": "New York",
    "postalCode": "10001",
    "stateProvince": "NY"
  }
}
```



---

### JWTUser



**User Details Model**: Represents authenticated user/customer in Spring Security.

```java
public class JWTUser implements UserDetails {

    private final Long id;
    private final String username;
    private final String firstname;
    private final String lastname;
    private final String email;
    private final String password;
    private final Collection<? extends GrantedAuthority> authorities;
    private final boolean enabled;
    private final Date lastPasswordResetDate;

    // UserDetails interface methods
    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return authorities;
    }

    @Override
    public boolean isAccountNonExpired() { return true; }

    @Override
    public boolean isAccountNonLocked() { return true; }

    @Override
    public boolean isCredentialsNonExpired() { return true; }

    @Override
    public boolean isEnabled() { return enabled; }
}
```

**Key Fields:**
- `id`: User/Customer database ID
- `username`: Login username (email)
- `authorities`: List of granted authorities/permissions
- `lastPasswordResetDate`: Used for token invalidation after password change

**Authorities Format:**
- Admin: `ROLE_AUTH`, plus permission-based authorities
- Customer: `ROLE_AUTH_CUSTOMER`, plus permission-based authorities

**Code Reference:** `JWTUser.java` (in `sm-shop/store/security/user/`)



---

## Configuration Properties

### JWT Configuration



**Required Configuration**: JWT token settings must be provided.

The following properties must be configured (typically in `application.properties` or environment variables):

```properties
# JWT Secret Key (must be secure and sufficiently long)
jwt.secret=YourSecureSecretKeyHereShouldBeLongAndRandom123456789

# JWT Expiration Time (in seconds)
# Example: 3600 = 1 hour, 86400 = 24 hours
jwt.expiration=3600

# Authorization Header Name
authToken.header=Authorization
```


### Password Policy Configuration

```properties
# Password Expiration Period (in days)
password.expiration.days=180  # 6 months

# Password History Size
password.history.size=5

# Password Complexity Requirements
password.complexity.minLength=8
password.complexity.requireLowercase=true
password.complexity.requireUppercase=true
password.complexity.requireDigit=true
password.complexity.requireSpecialChar=true
password.complexity.specialChars=!@#$%^&*()_+-=[]{}|;:,.<>?

# Legacy User Support
password.policy.legacyUserExemption=true
password.policy.checkComplexityOnLogin=false  # Only check expiration on login
```


**Configuration Details:**

| Property | Type | Description | Example |
|----------|------|-------------|---------|
| `jwt.secret` | String | Secret key for signing JWT tokens (HMAC SHA-512) | `MySecretKey123...` |
| `jwt.expiration` | Long | Token expiration time in seconds | `3600` (1 hour) |
| `authToken.header` | String | HTTP header name for token | `Authorization` |


| `password.expiration.days` | Integer | Password expiration period in days | `180` (6 months) |
| `password.history.size` | Integer | Number of previous passwords to track | `5` |
| `password.complexity.minLength` | Integer | Minimum password length | `8` |
| `password.policy.legacyUserExemption` | Boolean | Exempt legacy users from expiration | `true` |


**Security Best Practices:**

1. **Secret Key**:
   - Use a strong, randomly generated secret
   - Minimum 512 bits (64 characters) for HS512 algorithm
   - Store in environment variables or secure vault
   - Never commit to version control

2. **Expiration Time**:
   - Balance security vs. user experience
   - Shorter expiration = more secure, but more frequent re-authentication
   - Typical values: 1 hour (API), 24 hours (mobile)

3. **Token Refresh**:
   - Implement token refresh to extend sessions without re-login
   - Grace period: 200 seconds (configurable)


4. **Password Expiration**:
   - 6-month expiration balances security and usability
   - Legacy users (existing users during migration) are exempt
   - First password change activates full policy enforcement

5. **Password History**:
   - Tracking last 5 passwords prevents pattern reuse
   - Hashed using same BCrypt algorithm as passwords
   - Automatically maintains only most recent 5 entries


**Environment Variable Configuration:**

```bash
export JWT_SECRET="YourSecureSecretKeyHereShouldBeLongAndRandom123456789"
export JWT_EXPIRATION=3600
export AUTH_TOKEN_HEADER="Authorization"
```


```bash
export PASSWORD_EXPIRATION_DAYS=180
export PASSWORD_HISTORY_SIZE=5
export PASSWORD_MIN_LENGTH=8
```


**Docker Configuration:**

```dockerfile
ENV JWT_SECRET=YourSecureSecretKeyHere
ENV JWT_EXPIRATION=3600
ENV AUTH_TOKEN_HEADER=Authorization
```


```dockerfile
ENV PASSWORD_EXPIRATION_DAYS=180
ENV PASSWORD_HISTORY_SIZE=5
```


**Note**: These properties are referenced using Spring's `@Value` annotation:
```java
@Value("${jwt.secret}")
private String secret;

@Value("${jwt.expiration}")
private Long expiration;

@Value("${authToken.header}")
private String tokenHeader;
```


```java
@Value("${password.expiration.days}")
private Integer passwordExpirationDays;

@Value("${password.history.size}")
private Integer passwordHistorySize;
```


**Code Reference:** `JWTTokenUtil.java:50-54`



---

## Implementation Details

### User Details Service - Admin



**Admin User Loading**: How admin users are loaded and authenticated.

```java
@Service("jwtAdminDetailsService")
public class JWTAdminServicesImpl implements UserDetailsService {

    @Inject
    private UserService userService;

    @Inject
    private PermissionService permissionService;

    @Inject
    private GroupService groupService;

    @Override
    public UserDetails loadUserByUsername(String userName)
            throws UsernameNotFoundException {

        // 1. Load user from database
        User user = userService.getByUserName(userName);
        if(user == null) {
            throw new UsernameNotFoundException("User " + userName + " not found");
        }

        // 2. Build authorities collection
        Collection<GrantedAuthority> authorities = new ArrayList<>();

        // Add base authentication role
        GrantedAuthority role = new SimpleGrantedAuthority(
            ROLE_PREFIX + Constants.PERMISSION_AUTHENTICATED
        );
        authorities.add(role);

        // 3. Load group-based permissions
        List<Integer> groupsId = user.getGroups().stream()
            .map(Group::getId)
            .collect(Collectors.toList());

        if(CollectionUtils.isNotEmpty(groupsId)) {
            List<Permission> permissions = permissionService.getPermissions(groupsId);
            for(Permission permission : permissions) {
                GrantedAuthority auth = new SimpleGrantedAuthority(
                    permission.getPermissionName()
                );
                authorities.add(auth);
            }
        }

        // 4. Create JWTUser with authorities
        return new JWTUser(
            user.getId(),
            userName,
            user.getFirstName(),
            user.getLastName(),
            user.getAdminEmail(),
            user.getAdminPassword(),
            authorities,
            true,  // enabled
            null   // lastPasswordResetDate (not tracked for admins)
        );
    }
}
```

**Key Steps:**

1. **User Lookup**: Query `User` entity by username
2. **Base Role**: Add `ROLE_AUTHENTICATED` for all authenticated users
3. **Group Permissions**: Load all permissions from user's groups
4. **Authority Mapping**: Convert permissions to `GrantedAuthority` objects
5. **JWTUser Creation**: Create Spring Security `UserDetails` object

**Permission Examples:**
- `PRODUCT_CREATE`
- `ORDER_MANAGEMENT`
- `CUSTOMER_VIEW`
- `STORE_ADMIN`

**Code Reference:** `JWTAdminServicesImpl.java:49-112`



---

### User Details Service - Customer



**Customer Loading**: How customer accounts are loaded and authenticated.

```java
@Service("jwtCustomerDetailsService")
public class JWTCustomerServicesImpl extends AbstractCustomerServices {

    @Inject
    public JWTCustomerServicesImpl(
            CustomerService customerService,
            PermissionService permissionService,
            GroupService groupService) {
        super(customerService, permissionService, groupService);
    }

    @Override
    protected UserDetails userDetails(String userName,
                                       Customer customer,
                                       Collection<GrantedAuthority> authorities) {

        Date lastModified = null;
        // lastModified could be tracked from AuditSection if needed

        return new JWTUser(
            customer.getId(),
            userName,
            customer.getBilling().getFirstName(),
            customer.getBilling().getLastName(),
            customer.getEmailAddress(),
            customer.getPassword(),
            authorities,
            true,  // enabled
            lastModified
        );
    }
}
```

**Abstract Base Class (AbstractCustomerServices):**

```java
public abstract class AbstractCustomerServices implements UserDetailsService {

    protected CustomerService customerService;
    protected PermissionService permissionService;
    protected GroupService groupService;

    @Override
    public UserDetails loadUserByUsername(String userName)
            throws UsernameNotFoundException {

        // 1. Load customer by nickname (username)
        Customer user = customerService.getByNick(userName);
        if(user == null) {
            throw new UsernameNotFoundException("User " + userName + " not found");
        }

        // 2. Build authorities
        Collection<GrantedAuthority> authorities = new ArrayList<>();

        // Add customer authentication role
        GrantedAuthority role = new SimpleGrantedAuthority(
            ROLE_PREFIX + Constants.PERMISSION_CUSTOMER_AUTHENTICATED
        );
        authorities.add(role);

        // 3. Load group-based permissions
        List<Integer> groupsId = user.getGroups().stream()
            .map(Group::getId)
            .collect(Collectors.toList());

        if(CollectionUtils.isNotEmpty(groupsId)) {
            List<Permission> permissions = permissionService.getPermissions(groupsId);
            for(Permission permission : permissions) {
                GrantedAuthority auth = new SimpleGrantedAuthority(
                    permission.getPermissionName()
                );
                authorities.add(auth);
            }
        }

        // 4. Delegate to subclass for JWTUser creation
        return userDetails(userName, user, authorities);
    }
}
```

**Key Differences from Admin:**

1. **Lookup Method**: Uses `customerService.getByNick()` instead of `getByUserName()`
2. **Base Role**: `ROLE_AUTH_CUSTOMER` instead of `ROLE_AUTH`
3. **Name Source**: Customer name from `billing` address
4. **Email Source**: Customer `emailAddress` field

**Code References:**
- Customer Service: `JWTCustomerServicesImpl.java:34-54`
- Abstract Base: `AbstractCustomerServices.java:50-94`



---


### Password Policy Service

The `PasswordPolicyService` handles all password policy enforcement, history management, and validation.

**Service Interface:**

```java
@Service
public class PasswordPolicyServiceImpl implements PasswordPolicyService {

    @Inject
    private PasswordHistoryRepository passwordHistoryRepository;

    @Inject
    private PasswordEncoder passwordEncoder;

    @Value("${password.expiration.days}")
    private Integer passwordExpirationDays;

    @Value("${password.history.size}")
    private Integer passwordHistorySize;

    @Value("${password.policy.legacyUserExemption}")
    private Boolean legacyUserExemption;

    /**
     * Check password policy for a user
     */
    @Override
    public PasswordPolicyStatus checkPolicy(JWTUser user) {
        PasswordPolicyStatus status = new PasswordPolicyStatus();

        // Check if legacy user (exempt from expiration)
        if (user.getLastPasswordResetDate() == null && legacyUserExemption) {
            status.setLegacyUser(true);
            status.setExpired(false);
            status.setViolatesComplexity(false);
            return status;
        }

        // Check password expiration
        if (user.getLastPasswordResetDate() != null) {
            Date expirationDate = calculateExpirationDate(user.getLastPasswordResetDate());
            status.setExpired(new Date().after(expirationDate));
            status.setPasswordExpiration(expirationDate);
        }

        status.setLastPasswordUpdate(user.getLastPasswordResetDate());
        status.setLegacyUser(false);

        return status;
    }

    /**
     * Validate password complexity
     */
    @Override
    public List<String> validatePasswordComplexity(String password) {
        List<String> violations = new ArrayList<>();

        if (password.length() < 8) {
            violations.add("Password must be at least 8 characters long");
        }

        if (!password.matches(".*[a-z].*")) {
            violations.add("Password must contain at least one lowercase letter");
        }

        if (!password.matches(".*[A-Z].*")) {
            violations.add("Password must contain at least one uppercase letter");
        }

        if (!password.matches(".*\\d.*")) {
            violations.add("Password must contain at least one digit");
        }

        if (!password.matches(".*[!@#$%^&*()_+\\-=\\[\\]{}|;:,.<>?].*")) {
            violations.add("Password must contain at least one special character");
        }

        return violations;
    }

    /**
     * Check if password exists in user's history
     */
    @Override
    public boolean isPasswordInHistory(Long userId, String newPassword) {
        List<PasswordHistory> history = passwordHistoryRepository
            .findTopNByUserIdOrderByChangedDateDesc(userId, passwordHistorySize);

        for (PasswordHistory entry : history) {
            if (passwordEncoder.matches(newPassword, entry.getPasswordHash())) {
                return true;
            }
        }

        return false;
    }

    /**
     * Add password to history and maintain history size
     */
    @Override
    public void addToPasswordHistory(Long userId, String passwordHash) {
        // Add new entry
        PasswordHistory newEntry = new PasswordHistory();
        newEntry.setUserId(userId);
        newEntry.setPasswordHash(passwordHash);
        newEntry.setChangedDate(new Date());
        passwordHistoryRepository.save(newEntry);

        // Remove old entries beyond history size
        List<PasswordHistory> history = passwordHistoryRepository
            .findAllByUserIdOrderByChangedDateDesc(userId);

        if (history.size() > passwordHistorySize) {
            List<PasswordHistory> toRemove = history.subList(passwordHistorySize, history.size());
            passwordHistoryRepository.deleteAll(toRemove);
        }
    }

    /**
     * Calculate password expiration date
     */
    private Date calculateExpirationDate(Date lastPasswordUpdate) {
        Calendar calendar = Calendar.getInstance();
        calendar.setTime(lastPasswordUpdate);
        calendar.add(Calendar.DAY_OF_YEAR, passwordExpirationDays);
        return calendar.getTime();
    }

    /**
     * Log password change event
     */
    @Override
    public void logPasswordChange(Long userId, String username) {
        LOGGER.info("Password changed for user: {} (ID: {})", username, userId);
        // Additional audit logging implementation
    }
}
```

**Key Methods:**

1. **checkPolicy(JWTUser)**: Validates password expiration and complexity
2. **validatePasswordComplexity(String)**: Checks password against complexity rules
3. **isPasswordInHistory(Long, String)**: Verifies password not in last 5
4. **addToPasswordHistory(Long, String)**: Adds password to history and maintains size limit
5. **logPasswordChange(Long, String)**: Audit logging for password changes

**Database Schema (PasswordHistory):**

```sql
CREATE TABLE password_history (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    changed_date TIMESTAMP NOT NULL,
    INDEX idx_user_changed (user_id, changed_date DESC)
);
```

**Code Reference:** `PasswordPolicyServiceImpl.java` *(to be implemented)*


---

### Authentication Providers



**Authentication Provider Pattern**: How Spring Security validates credentials.

#### Admin Authentication Provider

```java
@Component
public class JWTAdminAuthenticationProvider extends DaoAuthenticationProvider {

    @Inject
    public void setUserDetailsService(UserDetailsService userDetailsService) {
        super.setUserDetailsService(userDetailsService);
    }

    @Inject
    public void setPasswordEncoder(PasswordEncoder passwordEncoder) {
        super.setPasswordEncoder(passwordEncoder);
    }
}
```

#### Customer Authentication Provider

```java
@Component
public class JWTCustomerAuthenticationProvider extends DaoAuthenticationProvider {

    @Inject
    public void setUserDetailsService(UserDetailsService userDetailsService) {
        super.setUserDetailsService(userDetailsService);
    }

    @Inject
    public void setPasswordEncoder(PasswordEncoder passwordEncoder) {
        super.setPasswordEncoder(passwordEncoder);
    }
}
```

**How It Works:**

1. **DaoAuthenticationProvider**: Spring Security's built-in provider for database authentication
2. **UserDetailsService**: Loads user from database (admin or customer)
3. **PasswordEncoder**: BCrypt encoder validates password
4. **Authentication Process**:
   - Load user details via `UserDetailsService`
   - Compare provided password with stored hash
   - If match, create `Authentication` object with authorities
   - If no match, throw `BadCredentialsException`

**Password Encoding:**

```java
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder();
}
```

BCrypt is used for all password hashing:
- Strong adaptive hash algorithm
- Automatically salted
- Configurable work factor (default: 10)

**Code References:**
- Admin Provider: `JWTAdminAuthenticationProvider.java`
- Customer Provider: `JWTCustomerAuthenticationProvider.java`
- Password Encoder: `MultipleEntryPointsSecurityConfig.java:56-58`



---

## Error Handling

### Authentication Errors



**Error Response Handling**: How authentication failures are handled.

#### 1. Bad Credentials (401 Unauthorized)

**Cause:** Invalid username or password

**Admin Login Error:**
```java
try {
    authentication = jwtAdminAuthenticationManager.authenticate(
        new UsernamePasswordAuthenticationToken(username, password)
    );
} catch(BadCredentialsException e) {
    return new ResponseEntity<>("{\"message\":\"Bad credentials\"}",
                                HttpStatus.UNAUTHORIZED);
}
```

**Response:**
```http
HTTP/1.1 401 Unauthorized
Content-Type: application/json

{"message":"Bad credentials"}
```

**Customer Login Error:**
```java
try {
    authentication = jwtCustomerAuthenticationManager.authenticate(
        new UsernamePasswordAuthenticationToken(username, password)
    );
} catch(BadCredentialsException e) {
    return new ResponseEntity<>("{\"message\":\"Bad credentials\"}",
                                HttpStatus.UNAUTHORIZED);
}
```

---

#### 2. User Not Found (404 Not Found / 500 Internal Server Error)

**Cause:** Username doesn't exist in database

**Admin Login Error:**
```java
} catch(Exception e) {
    if(e instanceof BadCredentialsException) {
        return new ResponseEntity<>("{\"message\":\"Bad credentials\"}",
                                    HttpStatus.UNAUTHORIZED);
    }
    LOGGER.error("Error during authentication " + e.getMessage());
    return new ResponseEntity<>(HttpStatus.NOT_FOUND);
}
```

**Response:**
```http
HTTP/1.1 404 Not Found
```

**Customer Login Error:**
```java
} catch(Exception e) {
    return new ResponseEntity<>(HttpStatus.INTERNAL_SERVER_ERROR);
}
```

**Response:**
```http
HTTP/1.1 500 Internal Server Error
```

---


#### 3. Password Change Required (403 Forbidden)

**Cause:** Password expired or doesn't meet current policy requirements

**Login Error Response:**
```java
} catch(PasswordExpiredException e) {
    return new ResponseEntity<>(
        "{\"requiresPasswordChange\":true,\"reason\":\"expired\",\"message\":\"Your password has expired\"}",
        HttpStatus.FORBIDDEN
    );
} catch(PasswordPolicyException e) {
    return new ResponseEntity<>(
        "{\"requiresPasswordChange\":true,\"reason\":\"policy_violation\",\"message\":\"Password doesn't meet requirements\"}",
        HttpStatus.FORBIDDEN
    );
}
```

**Response:**
```http
HTTP/1.1 403 Forbidden
Content-Type: application/json

{
  "requiresPasswordChange": true,
  "reason": "expired",
  "message": "Your password has expired. Please change your password to continue."
}
```

or

```http
HTTP/1.1 403 Forbidden
Content-Type: application/json

{
  "requiresPasswordChange": true,
  "reason": "policy_violation",
  "message": "Your password does not meet current security requirements."
}
```

**Client Handling:**
Client should redirect user to mandatory password change interface when receiving this response.


---

#### 4. Registration Conflict (409 Conflict)

**Cause:** Customer email already registered

```java
if(customerFacade.checkIfUserExists(customer.getUserName(), merchantStore)) {
    throw new GenericRuntimeException("409",
        "Customer with email [" + customer.getEmailAddress() + "] is already registered"
    );
}
```

**Response:**
```http
HTTP/1.1 409 Conflict
Content-Type: application/json

"Customer with email [customer@example.com] is already registered"
```

---

#### 5. Validation Errors (400 Bad Request)

**Cause:** Missing required fields or invalid data

**Example: Missing username**
```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "errors": [
    {
      "field": "username",
      "message": "Username cannot be empty"
    }
  ]
}
```

**Example: Missing billing country**
```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

"Requires customer Country code"
```


**Example: Password complexity violation**
```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "errors": [
    {
      "field": "password",
      "code": "INSUFFICIENT_UPPERCASE",
      "message": "Password must contain at least 1 uppercase character"
    },
    {
      "field": "password",
      "code": "INSUFFICIENT_SPECIAL",
      "message": "Password must contain at least 1 special character"
    }
  ]
}
```

**Example: Password in history**
```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": "password_reused",
  "message": "You cannot reuse any of your last 5 passwords"
}
```


---

#### 6. Token Refresh Errors (400 Bad Request)

**Cause:** Token cannot be refreshed (expired beyond grace period)

```java
if (jwtTokenUtil.canTokenBeRefreshed(token, user.getLastPasswordResetDate())) {
    String refreshedToken = jwtTokenUtil.refreshToken(token);
    return ResponseEntity.ok(new AuthenticationResponse(user.getId(), refreshedToken));
} else {
    return ResponseEntity.badRequest().body(null);
}
```

**Response:**
```http
HTTP/1.1 400 Bad Request
```

---

#### 7. Password Change Errors

**Cause: Customer not found**
```http
HTTP/1.1 404 Not Found
```

**Cause: Current password mismatch**
```http
HTTP/1.1 404 Not Found
Content-Type: application/json

"Username or password does not match"
```

**Cause: New passwords don't match**
```http
HTTP/1.1 404 Not Found
Content-Type: application/json

"Both passwords do not match"
```

---

#### 8. Unauthorized Access (401 Unauthorized)

**Cause:** Missing or invalid JWT token for protected endpoint

**Response:**
```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Basic realm="api-admin-realm"
```

or

```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Basic realm="api-customer-realm"
```

---

#### 9. Forbidden Access (403 Forbidden)

**Cause:** Valid token but insufficient permissions

**Response:**
```http
HTTP/1.1 403 Forbidden
```

**Code References:**
- Admin Errors: `AuthenticateUserApi.java:83-93`
- Customer Errors: `AuthenticateCustomerApi.java:176-184`
- Registration Errors: `AuthenticateCustomerApi.java:108-111`



---

## Security Considerations

### Best Practices



**Security Recommendations**: Guidelines for secure authentication implementation.

#### 1. JWT Secret Management

**Critical Security Requirement:**

```java
@Value("${jwt.secret}")
private String secret;
```

**Recommendations:**
- ✅ Store in environment variables or secure vault (HashiCorp Vault, AWS Secrets Manager)
- ✅ Use minimum 512-bit (64 character) random string
- ✅ Rotate secrets periodically
- ✅ Never commit to version control
- ❌ Do NOT hardcode in application.properties
- ❌ Do NOT use weak or predictable secrets

**Example Secure Secret Generation:**
```bash
openssl rand -base64 64
```

---

#### 2. Token Expiration Strategy

**Balance Security vs. UX:**

| Use Case | Recommended Expiration | Rationale |
|----------|----------------------|-----------|
| Admin API | 1-4 hours | Frequent access, higher security needs |
| Customer Web | 4-8 hours | Balance between security and convenience |
| Customer Mobile | 24-48 hours | Reduce login friction, use refresh tokens |
| Refresh Tokens | 7-30 days | Long-lived, single-use tokens |

**Current Configuration:**
```properties
jwt.expiration=3600  # 1 hour (3600 seconds)
```

**Refresh Token Strategy:**
- Grace period: 200 seconds
- Allows token refresh before expiration
- Invalidates on password change

---

#### 3. Password Security

**BCrypt Configuration:**

```java
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder();
}
```

**Recommendations:**
- ✅ BCrypt work factor: 10-12 (default: 10)
- ✅ Implement password complexity requirements (Passay library)
- ✅ Enforce minimum password length (8+ characters)
- ✅ Rate limit login attempts
- ✅ Implement account lockout after failed attempts
- ❌ Never log passwords
- ❌ Never return password in API responses


**Enhanced Password Validation**:
- ✅ Enforce complexity requirements (uppercase, lowercase, digit, special character)
- ✅ Track password history (last 5 passwords)
- ✅ Implement 6-month password expiration
- ✅ Provide real-time password validation feedback
- ✅ Legacy user exemption for backward compatibility
- ✅ Audit log all password changes


**Password Validation (Passay):**
Shopizer uses Passay for password validation. Configure rules in:
`sm-shop/validation/PasswordValidator.java`

---

#### 4. HTTPS/TLS Requirements

**Transport Security:**

- ✅ Always use HTTPS in production
- ✅ Enforce TLS 1.2+ only
- ✅ Use strong cipher suites
- ❌ Never transmit tokens over HTTP
- ❌ Never allow mixed content (HTTP + HTTPS)

**Spring Boot HTTPS Configuration:**
```properties
server.ssl.enabled=true
server.ssl.key-store=classpath:keystore.p12
server.ssl.key-store-password=${KEYSTORE_PASSWORD}
server.ssl.key-store-type=PKCS12
server.ssl.key-alias=tomcat
```

---

#### 5. Token Storage (Client-Side)

**Secure Storage Options:**

| Storage Type | Security Level | Use Case |
|--------------|---------------|----------|
| Memory (JS variable) | ⭐⭐⭐⭐⭐ | Single-page apps, lost on refresh |
| LocalStorage | ⭐⭐ | Persistent, vulnerable to XSS |
| SessionStorage | ⭐⭐⭐ | Cleared on tab close |
| HttpOnly Cookie | ⭐⭐⭐⭐ | Protected from XSS, requires CSRF protection |
| Secure HttpOnly Cookie | ⭐⭐⭐⭐⭐ | Best for web apps |

**Recommendations:**
- ✅ Use HttpOnly + Secure cookies for web apps
- ✅ Implement CSRF protection with cookies
- ✅ Use secure storage on mobile (Keychain/KeyStore)
- ❌ Avoid LocalStorage if possible (XSS risk)
- ❌ Never store in plain text files

---

#### 6. CORS Configuration

**Current Configuration:**

```java
response.setHeader("Access-Control-Allow-Origin", origin);
response.setHeader("Access-Control-Allow-Methods", "POST, GET, PUT, OPTIONS, DELETE, PATCH");
response.setHeader("Access-Control-Allow-Headers", "X-Auth-Token, Content-Type, Authorization, Cache-Control");
response.setHeader("Access-Control-Allow-Credentials", "true");
```

**Recommendations:**
- ✅ Whitelist specific origins (not `*`)
- ✅ Enable credentials only for trusted origins
- ✅ Restrict allowed methods to necessary ones
- ❌ Never use `Access-Control-Allow-Origin: *` with credentials
- ❌ Don't expose sensitive headers

**Improved Configuration:**
```properties
shopizer.cors.allowed-origins=https://yourdomain.com,https://admin.yourdomain.com
shopizer.cors.allowed-methods=GET,POST,PUT,DELETE
shopizer.cors.allowed-headers=Authorization,Content-Type
shopizer.cors.max-age=3600
```

---

#### 7. Rate Limiting

**Not Implemented (Recommendation):**

Implement rate limiting to prevent brute-force attacks:

```java
// Example using Bucket4j library
@Component
public class RateLimitingFilter extends OncePerRequestFilter {

    private final Bucket bucket = Bucket.builder()
        .addLimit(Bandwidth.classic(5, Refill.greedy(5, Duration.ofMinutes(1))))
        .build();

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                     HttpServletResponse response,
                                     FilterChain chain) {
        if (request.getRequestURI().contains("/login")) {
            if (!bucket.tryConsume(1)) {
                response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
                return;
            }
        }
        chain.doFilter(request, response);
    }
}
```

**Recommended Limits:**
- Login endpoints: 5 attempts per minute per IP
- Registration: 3 attempts per hour per IP
- Password reset: 3 attempts per hour per email
- Token refresh: 10 attempts per minute per user

---

#### 8. Logging and Monitoring

**Security Logging Best Practices:**

```java
// ✅ Good: Log authentication attempts
LOGGER.info("Authentication attempt for user: {}", username);

// ✅ Good: Log failures without details
LOGGER.warn("Failed authentication attempt for user: {}", username);

// ❌ Bad: Never log passwords
LOGGER.error("Login failed: " + username + " with password: " + password);

// ✅ Good: Log token validation failures
LOGGER.warn("Invalid token from IP: {}", request.getRemoteAddr());

// ✅ Good: Log suspicious activity
LOGGER.warn("Multiple failed login attempts from IP: {}", ipAddress);
```


**Enhanced Logging for Password Policy**:

```java
// ✅ Log password changes
LOGGER.info("Password changed for user: {} (ID: {})", username, userId);

// ✅ Log password expiration warnings
LOGGER.info("Password expired for user: {} (expired on: {})", username, expirationDate);

// ✅ Log password policy violations
LOGGER.warn("Password complexity violation for user: {}", username);

// ✅ Log password history violations
LOGGER.warn("Password reuse attempted for user: {}", username);
```


**Monitor for:**
- Failed login attempts (potential brute-force)
- Token validation failures
- Unusual access patterns
- Account lockouts
- Password reset requests


- Password expiration events
- Password change failures
- Password policy violations


---

#### 9. Token Revocation Strategy

**Current Limitation:**
No built-in token revocation mechanism.

**Recommended Implementation:**

```java
// Token blacklist using Redis
@Service
public class TokenBlacklistService {

    @Inject
    private RedisTemplate<String, String> redisTemplate;

    public void blacklistToken(String token, Date expiration) {
        long ttl = expiration.getTime() - System.currentTimeMillis();
        redisTemplate.opsForValue().set(
            "blacklist:" + token,
            "revoked",
            ttl,
            TimeUnit.MILLISECONDS
        );
    }

    public boolean isBlacklisted(String token) {
        return redisTemplate.hasKey("blacklist:" + token);
    }
}
```

**Use Cases:**
- Logout functionality
- Password change (invalidate old tokens)
- Account compromise (emergency revocation)
- User role change

---

#### 10. Additional Security Headers

**Recommended HTTP Security Headers:**

```java
// Add to AuthenticationTokenFilter or separate filter
response.setHeader("X-Content-Type-Options", "nosniff");
response.setHeader("X-Frame-Options", "DENY");
response.setHeader("X-XSS-Protection", "1; mode=block");
response.setHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
response.setHeader("Content-Security-Policy", "default-src 'self'");
response.setHeader("Referrer-Policy", "no-referrer");
```

---

#### 11. Input Validation

**Always Validate:**

```java
// ✅ Use Bean Validation
@Valid @RequestBody AuthenticationRequest request

// ✅ Sanitize user input
String username = StringUtils.trimToEmpty(request.getUsername());

// ✅ Validate email format
@Email(message="Invalid email format")
private String emailAddress;

// ❌ Never trust client input
// ❌ Don't use input directly in queries without validation
```

---

#### 12. Audit Trail

**Recommended Audit Logging:**

```java
@Entity
public class AuditLog {
    private Long id;
    private String username;
    private String action; // LOGIN, LOGOUT, PASSWORD_CHANGE, etc.
    private String ipAddress;
    private Date timestamp;
    private String userAgent;
    private boolean success;
}
```

**Track:**
- All authentication attempts (success/failure)
- Token generation events
- Password changes
- Account modifications
- Suspicious activities


**Enhanced Audit Trail for Password Policy**:

```java
@Entity
public class PasswordChangeAuditLog {
    private Long id;
    private Long userId;
    private String username;
    private Date changeDate;
    private String changedBy; // USER or ADMIN
    private String reason; // VOLUNTARY, EXPIRED, POLICY_VIOLATION
    private String ipAddress;
    private boolean success;
}
```

**Track:**
- All password change attempts (success/failure)
- Mandatory vs. voluntary password changes
- Password expiration events
- Password policy violations
- Password history violations


**Code Reference:** `AuthenticationTokenFilter.java:65-72` (IP capture)



---


### Password Policy Migration Strategy

When deploying the enhanced password policy system, follow this migration strategy to ensure backward compatibility with existing users:

#### Pre-Deployment Preparation

**1. Database Schema Updates**

Add new columns to user/customer tables:

```sql
ALTER TABLE CUSTOMER ADD COLUMN last_password_update DATETIME NULL DEFAULT NULL;
ALTER TABLE CUSTOMER ADD COLUMN password_expiration DATETIME NULL DEFAULT NULL;

CREATE TABLE PASSWORD_HISTORY (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    changed_date DATETIME NOT NULL,
    INDEX idx_user_changed (user_id, changed_date DESC)
);
```

**2. Set Legacy User Status**

Before deployment, mark all existing users as legacy users:

```sql
-- Mark all existing users as legacy (exempt from password expiration)
UPDATE CUSTOMER SET last_password_update = NULL WHERE last_password_update IS NULL OR last_password_update = '';

-- Clear password_expiration for all existing users
UPDATE CUSTOMER SET password_expiration = NULL;
```

#### Post-Deployment Behavior

**Legacy Users (last_password_update = NULL):**
- ✅ Can login with existing passwords (no expiration check)
- ✅ Can continue using the system without immediate password change
- ❌ Not subject to 6-month expiration rule
- ❌ Password history not checked during first password change

**After First Password Change:**
- ✅ `last_password_update` set to current timestamp
- ✅ `password_expiration` set to 6 months from now
- ✅ Password added to password history
- ✅ Full policy enforcement begins (expiration, history checks)

#### Gradual Enforcement Options

**Option 1: Voluntary Adoption (Recommended)**
- Legacy users exempt indefinitely
- Users change passwords voluntarily or when they forget
- Natural migration over time

**Option 2: Phased Enforcement**
- Set grace period (e.g., 90 days)
- After grace period, require all users to change passwords
- Display warning banner for legacy users

**Option 3: Immediate Enforcement with Exception**
- Enforce policy for all new logins
- Allow one-time legacy login to change password
- Require password change on next login

#### Communication Plan

**User Notifications:**

1. **Email Notification** (sent to all existing users):
   ```
   Subject: Enhanced Security: New Password Requirements

   We've enhanced our password security to better protect your account.

   What's New:
   - Stronger password requirements (uppercase, lowercase, numbers, special characters)
   - Password expiration after 6 months
   - Prevention of password reuse (last 5 passwords)

   Action Required:
   - Your current password will continue to work
   - When you change your password next, new requirements will apply
   - We recommend updating your password at your convenience

   Questions? Contact support@example.com
   ```

2. **In-App Banner** (displayed to legacy users):
   ```
   ℹ️ Your account is using our previous password policy.
   For enhanced security, consider updating your password.
   [Update Password]
   ```

#### Monitoring Migration Progress

Track migration progress with this query:

```sql
SELECT
    COUNT(*) as total_users,
    SUM(CASE WHEN last_password_update IS NULL THEN 1 ELSE 0 END) as legacy_users,
    SUM(CASE WHEN last_password_update IS NOT NULL THEN 1 ELSE 0 END) as migrated_users,
    ROUND(SUM(CASE WHEN last_password_update IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as migration_percentage
FROM CUSTOMER;
```

#### Rollback Plan

If issues arise, rollback is simple:

1. **Disable Policy Enforcement:**
   ```properties
   password.policy.legacyUserExemption=true
   password.policy.checkComplexityOnLogin=false
   ```

2. **Revert Database (if needed):**
   ```sql
   -- Mark all users as legacy again
   UPDATE CUSTOMER SET last_password_update = NULL;

   -- Clear password history (if desired)
   TRUNCATE TABLE PASSWORD_HISTORY;
   ```

3. **Redeploy Previous Version**

#### Testing Checklist

Before deployment:

- [ ] Test legacy user login (should succeed without policy check)
- [ ] Test new user registration (should enforce complexity)
- [ ] Test legacy user password change (should enforce policy after change)
- [ ] Test password history (ensure last 5 passwords rejected)
- [ ] Test password expiration (after 6 months)
- [ ] Test mandatory password change flow
- [ ] Verify database migration scripts
- [ ] Test rollback procedure
- [ ] Load test password validation performance
- [ ] Verify audit logging works correctly


---

## Appendix

### API Testing Examples



**Postman/cURL Examples**: Complete testing scenarios.

#### Admin Login

```bash
curl -X POST http://localhost:8080/api/v1/private/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin@shopizer.com",
    "password": "password"
  }'
```

**Expected Response:**
```json
{
  "id": 1,
  "token": "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJhZG1pbkBzaG9waXplci5jb20iLCJhdWQiOiJhcGkiLCJpYXQiOjE2MzI0MjcyMDAsImV4cCI6MTYzMjQzMDgwMH0.signature"
}
```

---

#### Customer Registration

```bash
curl -X POST http://localhost:8080/api/v1/customer/register \
  -H "Content-Type: application/json" \
  -H "store: DEFAULT" \
  -H "lang: en" \
  -d '{
    "emailAddress": "newcustomer@example.com",
    "password": "SecurePass123",
    "billing": {
      "firstName": "John",
      "lastName": "Doe",
      "country": "US",
      "address": "123 Main St",
      "city": "New York",
      "postalCode": "10001"
    }
  }'
```

**Expected Response:**
```json
{
  "id": 100,
  "token": "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJuZXdjdXN0b21lckBleGFtcGxlLmNvbSIsImF1ZCI6ImFwaSIsImlhdCI6MTYzMjQyNzIwMCwiZXhwIjoxNjMyNDMwODAwfQ.signature"
}
```

---

#### Customer Login

```bash
curl -X POST http://localhost:8080/api/v1/customer/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "customer@example.com",
    "password": "CustomerPass123"
  }'
```

**Expected Response:**
```json
{
  "id": 100,
  "token": "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJjdXN0b21lckBleGFtcGxlLmNvbSIsImF1ZCI6ImFwaSIsImlhdCI6MTYzMjQyNzIwMCwiZXhwIjoxNjMyNDMwODAwfQ.signature"
}
```

---


#### Customer Login (Password Expired)

```bash
curl -X POST http://localhost:8080/api/v1/customer/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "olduser@example.com",
    "password": "ExpiredPass123"
  }'
```

**Expected Response:**
```json
{
  "requiresPasswordChange": true,
  "reason": "expired",
  "message": "Your password has expired. Please change your password to continue."
}
```

**HTTP Status:** 403 Forbidden

---

#### Mandatory Password Change

```bash
curl -X POST http://localhost:8080/api/v1/auth/change-password \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "username": "olduser@example.com",
    "newPassword": "NewSecurePass123!",
    "repeatPassword": "NewSecurePass123!"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Password changed successfully"
}
```

**HTTP Status:** 200 OK

---

#### Password Change with Validation Error

```bash
curl -X POST http://localhost:8080/api/v1/auth/change-password \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "username": "user@example.com",
    "newPassword": "weak",
    "repeatPassword": "weak"
  }'
```

**Expected Response:**
```json
{
  "errors": [
    {
      "field": "password",
      "code": "TOO_SHORT",
      "message": "Password must be at least 8 characters long"
    },
    {
      "field": "password",
      "code": "INSUFFICIENT_UPPERCASE",
      "message": "Password must contain at least 1 uppercase character"
    },
    {
      "field": "password",
      "code": "INSUFFICIENT_DIGIT",
      "message": "Password must contain at least 1 digit"
    },
    {
      "field": "password",
      "code": "INSUFFICIENT_SPECIAL",
      "message": "Password must contain at least 1 special character"
    }
  ]
}
```

**HTTP Status:** 400 Bad Request

---

#### Password Change with History Violation

```bash
curl -X POST http://localhost:8080/api/v1/auth/change-password \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{
    "username": "user@example.com",
    "newPassword": "PreviousPass123!",
    "repeatPassword": "PreviousPass123!"
  }'
```

**Expected Response:**
```json
{
  "error": "password_reused",
  "message": "You cannot reuse any of your last 5 passwords"
}
```

**HTTP Status:** 400 Bad Request


---

#### Access Protected Resource (Admin)

```bash
curl -X GET http://localhost:8080/api/v1/private/products \
  -H "Authorization: Bearer eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJhZG1pbkBzaG9waXplci5jb20iLCJhdWQiOiJhcGkiLCJpYXQiOjE2MzI0MjcyMDAsImV4cCI6MTYzMjQzMDgwMH0.signature"
```

---

#### Access Protected Resource (Customer)

```bash
curl -X GET http://localhost:8080/api/v1/auth/customer/orders \
  -H "Authorization: Bearer eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJjdXN0b21lckBleGFtcGxlLmNvbSIsImF1ZCI6ImFwaSIsImlhdCI6MTYzMjQyNzIwMCwiZXhwIjoxNjMyNDMwODAwfQ.signature"
```

---

#### Token Refresh (Admin)

```bash
curl -X GET http://localhost:8080/api/v1/auth/refresh \
  -H "Authorization: Bearer eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJhZG1pbkBzaG9waXplci5jb20iLCJhdWQiOiJhcGkiLCJpYXQiOjE2MzI0MjcyMDAsImV4cCI6MTYzMjQzMDgwMH0.signature"
```

**Expected Response:**
```json
{
  "id": 1,
  "token": "eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJhZG1pbkBzaG9waXplci5jb20iLCJhdWQiOiJhcGkiLCJpYXQiOjE2MzI0MzA4MDAsImV4cCI6MTYzMjQzNDQwMH0.new-signature"
}
```

---

#### Token Refresh (Customer)

```bash
curl -X GET http://localhost:8080/api/v1/auth/customer/refresh \
  -H "Authorization: Bearer eyJhbGciOiJIUzUxMiJ9.eyJzdWIiOiJjdXN0b21lckBleGFtcGxlLmNvbSIsImF1ZCI6ImFwaSIsImlhdCI6MTYzMjQyNzIwMCwiZXhwIjoxNjMyNDMwODAwfQ.signature"
```

---

#### Change Customer Password

```bash
curl -X POST http://localhost:8080/api/v1/auth/customer/password \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <customer-token>" \
  -H "store: DEFAULT" \
  -d '{
    "username": "customer@example.com",
    "current": "OldPassword123",
    "password": "NewPassword456",
    "repeatPassword": "NewPassword456"
  }'
```

**Expected Response:**
```
HTTP/1.1 200 OK
```



---

### Common Issues and Troubleshooting



**Troubleshooting Guide**: Solutions to common authentication problems.

#### Issue 1: JWT Secret Not Configured

**Symptom:**
```
IllegalArgumentException: JWT secret cannot be null or empty
```

**Solution:**
```properties
# Add to application.properties or environment variables
jwt.secret=YourSecureSecretKeyHereShouldBeLongAndRandom123456789
jwt.expiration=3600
authToken.header=Authorization
```

---

#### Issue 2: Token Expired

**Symptom:**
```
ExpiredJwtException: JWT expired at 2023-09-15T10:30:00Z
```

**Solutions:**
1. Use token refresh endpoint
2. Re-authenticate user
3. Increase expiration time (if appropriate)

```bash
# Refresh token
curl -X GET http://localhost:8080/api/v1/auth/refresh \
  -H "Authorization: Bearer <expired-token>"
```

---

#### Issue 3: Bad Credentials

**Symptom:**
```json
{"message": "Bad credentials"}
```

**Possible Causes:**
1. Incorrect password
2. User doesn't exist
3. Account locked
4. Password not hashed correctly

**Debug Steps:**
1. Verify user exists in database
2. Check password hash format
3. Review authentication logs
4. Test with known working credentials

---


#### Issue 4: Password Change Required Error

**Symptom:**
```json
{
  "requiresPasswordChange": true,
  "reason": "expired",
  "message": "Your password has expired"
}
```

**Cause:**
Password is older than 6 months and user is not a legacy user

**Solution:**
1. Redirect user to mandatory password change page
2. User must change password before accessing system
3. New password must meet complexity requirements
4. Cannot reuse last 5 passwords

**Debug Steps:**
1. Check `last_password_update` in database
2. Verify password expiration date calculation
3. Confirm user is not legacy user (last_password_update != null)

---

#### Issue 5: Password Complexity Validation Fails

**Symptom:**
```json
{
  "errors": [
    {
      "field": "password",
      "message": "Password must contain at least one uppercase letter"
    }
  ]
}
```

**Cause:**
New password doesn't meet complexity requirements

**Solution:**
Ensure password meets all requirements:
- Minimum 8 characters
- At least 1 lowercase letter (a-z)
- At least 1 uppercase letter (A-Z)
- At least 1 digit (0-9)
- At least 1 special character (!@#$%^&*()_+-=[]{}|;:,.<>?)

**Debug Steps:**
1. Test password against each requirement individually
2. Check PasswordValidator configuration
3. Verify special character set matches configuration

---

#### Issue 6: Password History Violation

**Symptom:**
```json
{
  "error": "password_reused",
  "message": "You cannot reuse any of your last 5 passwords"
}
```

**Cause:**
New password matches one of the last 5 passwords

**Solution:**
Choose a different password that hasn't been used recently

**Debug Steps:**
1. Query password_history table for user
2. Verify BCrypt comparison logic
3. Check password_history size configuration
4. Ensure password hashes are stored correctly

---

#### Issue 7: Legacy User Not Exempt from Expiration

**Symptom:**
Legacy user (existing before migration) forced to change password on login

**Cause:**
`last_password_update` field not set to NULL during migration

**Solution:**
```sql
-- Mark user as legacy
UPDATE CUSTOMER SET last_password_update = NULL WHERE id = <user_id>;

-- Or mark all existing users as legacy
UPDATE CUSTOMER SET last_password_update = NULL
WHERE created_date < '<migration_date>';
```

**Debug Steps:**
1. Check `last_password_update` value in database
2. Verify migration script ran successfully
3. Check `password.policy.legacyUserExemption` configuration


---

#### Issue 8: CORS Errors

**Symptom:**
```
Access to XMLHttpRequest at 'http://localhost:8080/api/v1/customer/login'
from origin 'http://localhost:3000' has been blocked by CORS policy
```

**Solution:**
Check CORS headers in `AuthenticationTokenFilter`:
```java
response.setHeader("Access-Control-Allow-Origin", "http://localhost:3000");
response.setHeader("Access-Control-Allow-Credentials", "true");
```

---

#### Issue 9: Token Not Validated

**Symptom:**
Protected endpoint returns 401 even with valid token

**Debug Steps:**
1. Check token format: `Bearer <token>`
2. Verify token header name: `Authorization`
3. Check token signature
4. Verify endpoint path matches filter

```java
// Add debug logging
LOGGER.debug("Token: {}", requestHeader);
LOGGER.debug("Username: {}", jwtTokenUtil.getUsernameFromToken(token));
```

---

#### Issue 10: Customer Not Found by Username

**Symptom:**
```
UsernameNotFoundException: User customer@example.com not found
```

**Cause:**
Customer lookup uses `customerService.getByNick()` which searches the `nick` field, not `emailAddress`.

**Solution:**
Ensure customer registration sets the `nick` field:
```java
customer.setNick(customer.getEmailAddress());
```

---

#### Issue 11: Password Validation Fails

**Symptom:**
Registration fails with validation errors

**Cause:**
Passay password validation rules not met

**Solution:**
Review password requirements:
- Minimum length (usually 8 characters)
- At least one uppercase letter
- At least one lowercase letter
- At least one digit
- At least one special character (optional)

---

#### Issue 12: Multiple SecurityContext Issues

**Symptom:**
Admin token works for customer endpoints or vice versa

**Cause:**
Authentication managers not properly separated

**Solution:**
Verify filter routing in `AuthenticationTokenFilter`:
```java
// Customer endpoints
if(requestUrl.contains("/api/v1/auth")) {
    jwtCustomCustomerAuthenticationManager.authenticateRequest(request, response);
}

// Admin endpoints
if(requestUrl.contains("/api/v1/private")) {
    jwtCustomAdminAuthenticationManager.authenticateRequest(request, response);
}
```

---

#### Issue 13: Token Refresh Always Succeeds

**Symptom:**
Token refresh works even after password change

**Note:**
`canTokenBeRefreshedWithGrace()` is hardcoded to return `true` in the current implementation:
```java
public Boolean canTokenBeRefreshedWithGrace(String token, Date lastPasswordReset) {
    // ... validation logic ...
    return true; // Line 150 - always returns true
}
```

**Recommendation:**
Replace with proper validation:
```java
return !isCreatedBeforeLastPasswordResetWithGrace(created, lastPasswordReset)
        && (!isTokenExpiredWithGrace(token) || ignoreTokenExpiration(token));
```

---

#### Issue 14: Database Connection Issues

**Symptom:**
```
ServiceException: Cannot authenticate customer
```

**Debug Steps:**
1. Check database connectivity
2. Verify database schema exists
3. Check entity mappings
4. Review database logs

```bash
# Test database connection
curl http://localhost:8080/actuator/health
```



---

### Related Documentation

- [User Management Documentation](./user-management.md)
- [Customer Management Documentation](./customer-management.md)
- [Security Configuration Guide](./security-config.md)
- [API Reference Documentation](./api-reference.md)
- [Spring Security Documentation](https://docs.spring.io/spring-security/reference/)
- [JWT.io - JWT Debugger](https://jwt.io/)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)


- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [NIST Password Guidelines](https://pages.nist.gov/800-63-3/sp800-63b.html)


---

**Document Version:** 2.0
**Last Updated:** 2025-10-17
**Author:** Claude Code
**Status:** Approved
