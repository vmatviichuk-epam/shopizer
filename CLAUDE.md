# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Shopizer is a Java-based headless e-commerce platform built with Spring Boot. It provides REST APIs for catalog, shopping cart, checkout, merchant management, orders, customers, and user administration. The application exposes its API documentation at http://localhost:8080/swagger-ui.html.

## Build & Run Commands

### Building the Application

```bash
# Build from root (includes all modules)
./mvnw clean install

# Build and run the main application
cd sm-shop
./mvnw spring-boot:run
```

### Running Tests

```bash
# Run all tests from root
./mvnw test

# Run tests for specific module
cd sm-shop
./mvnw test

# Run a single test class
./mvnw test -Dtest=ShoppingCartAPIIntegrationTest

# Run a specific test method
./mvnw test -Dtest=CustomerRegistrationIntegrationTest#testRegisterCustomer
```

### Docker

```bash
# Run backend
docker run -p 8080:8080 shopizerecomm/shopizer:latest

# Run admin UI (requires backend running)
docker run -e "APP_BASE_URL=http://localhost:8080/api" -p 82:80 shopizerecomm/shopizer-admin

# Run React shop (requires backend running)
docker run -e "APP_MERCHANT=DEFAULT" -e "APP_BASE_URL=http://localhost:8080" -p 80:80 shopizerecomm/shopizer-shop-reactjs
```

### Maven Wrapper

This project uses the Maven Wrapper (`mvnw`/`mvnw.cmd`). Use `./mvnw` on Unix/Mac or `mvnw.cmd` on Windows instead of `mvn`.

## Architecture

### Multi-Module Maven Structure

The project is organized as a multi-module Maven project with clear separation of concerns:

- **Root POM** (`pom.xml`): Parent project defining shared dependencies, properties, and plugin configurations for all modules
- **sm-core-model**: Domain entities and JPA models (catalog, customer, order, merchant, payment, shipping, tax, user)
- **sm-core-modules**: External integration modules (payment providers, shipping providers, search utilities)
- **sm-core**: Business logic layer with services, repositories, and module implementations
- **sm-shop-model**: API request/response DTOs and data transfer objects
- **sm-shop**: REST API controllers, security configuration, and Spring Boot application entry point

### Dependency Flow

```
sm-shop (main application)
  ├── depends on: sm-core
  ├── depends on: sm-core-model
  └── depends on: sm-shop-model

sm-core (business layer)
  ├── depends on: sm-core-model
  └── depends on: sm-core-modules

sm-core-modules (integration modules)
  └── standalone (external integrations)

sm-shop-model (API DTOs)
  └── standalone

sm-core-model (domain model)
  └── standalone (JPA entities)
```

### Key Packages

**sm-core-model** (`com.salesmanager.core.model`):
- Domain entities organized by business domain (catalog, customer, order, merchant, payment, shipping, tax, user)
- JPA annotations and persistence mappings
- Core business model shared across all layers

**sm-core** (`com.salesmanager.core.business`):
- `services/`: Business service layer with implementations for each domain (catalog, customer, order, etc.)
- `repositories/`: Spring Data JPA repositories for data access
- `modules/`: Module interfaces and implementations for external integrations
- `configuration/`: Configuration classes for core business logic
- `utils/`: Business utility classes

**sm-core-modules** (`com.salesmanager.core.modules`):
- External integration implementations (payment gateways, shipping providers)
- Search functionality
- Integration utilities

**sm-shop-model** (`com.salesmanager.shop.model`):
- REST API request/response objects
- DTOs for API contracts

**sm-shop** (`com.salesmanager.shop`):
- `store.api.v1/`, `store.api.v2/`: Versioned REST API controllers organized by domain (catalog, customer, order, payment, product, store, tax, user)
- `store.facade/`: Facade pattern implementations coordinating between services and controllers
- `store.security/`: JWT authentication and Spring Security configuration
- `mapper/`: MapStruct mappers for converting between entities and DTOs
- `populator/`: Legacy populators for DTO transformation
- `application/`: Spring Boot main application class
- `filter/`: Request/response filters

### API Versioning

The REST API uses URL-based versioning:
- `/api/v1/`: Version 1 endpoints (stable)
- `/api/v2/`: Version 2 endpoints (newer features like product variants)

API controllers are organized by business domain within each version directory.

### Data Access Pattern

The application follows a layered architecture:
1. **Controllers** (REST API layer) in `sm-shop/store/api/`
2. **Facades** coordinate between controllers and services in `sm-shop/store/facade/`
3. **Services** (business logic) in `sm-core/business/services/`
4. **Repositories** (data access) in `sm-core/business/repositories/`
5. **Entities** (domain model) in `sm-core-model/model/`

### Technology Stack

- **Spring Boot 2.5.12** with Spring Data JPA
- **Java 11** (configurable to Java 17+)
- **Hibernate** with Ehcache for second-level caching
- **H2** (default/testing) or **MySQL** (production)
- **MapStruct** for entity-DTO mapping (annotation processor configured)
- **Swagger 2** for API documentation (Springfox)
- **JWT** (jjwt) for authentication
- **Drools** rules engine for business rules
- **Infinispan** for distributed caching
- **OpenSearch** for product search (optional)

### External Integrations

Payment providers (in `sm-core`):
- PayPal, Stripe, Braintree (included)
- Square (optional, commented in POM)

Storage providers:
- AWS S3, Google Cloud Storage

Email:
- AWS SES, SMTP

Shipping:
- Canada Post (spring-boot-starter)

Search:
- OpenSearch (spring-boot-starter)

## Configuration

**Default Database**: H2 in-memory (file: `sm-shop/SALESMANAGER.h2.db`)
**Default Schema**: SALESMANAGER
**Server Port**: 8080

Key configuration files:
- `sm-shop/src/main/resources/application.properties`: Main Spring Boot configuration
- `sm-shop/src/main/resources/shopizer-properties.properties`: Shopizer-specific settings
- `sm-shop/src/main/resources/vault.properties`: Secrets/vault configuration

To switch to MySQL, uncomment the MySQL dependency in `pom.xml` and configure connection properties in `application.properties`.

## Testing Strategy

Integration tests are located in `sm-shop/src/test/java/com/salesmanager/test/shop/integration/`:
- Tests use `@SpringBootTest` and include full application context
- Test categories: cart, category, customer, order, product, etc.
- Base class: `ServicesTestSupport` provides common test utilities

When adding new features, follow the existing pattern of creating API integration tests that exercise the full stack from REST controller through to database.

## Security

- Spring Security is configured with custom JWT-based authentication
- Password validation using Passay library with custom rules
- XSS protection with OWASP AntiSamy
- API endpoints secured with role-based access control
- Security configuration in `sm-shop/store/security/`

## Common Development Workflows

When adding a new API endpoint:
1. Create/update entity in `sm-core-model/model/`
2. Create/update repository in `sm-core/business/repositories/`
3. Create/update service in `sm-core/business/services/`
4. Create request/response DTOs in `sm-shop-model/`
5. Create MapStruct mapper in `sm-shop/mapper/`
6. Create facade in `sm-shop/store/facade/`
7. Create REST controller in `sm-shop/store/api/v1/` or `v2/`
8. Add integration tests in `sm-shop/src/test/`

When modifying entity mappings, be aware that MapStruct annotation processors run during compilation and generate mapper implementations in `target/generated-sources/annotations/`.

## Documentation Management

### Documentation Location

Component documentation is stored in the `docs/` folder. This includes:
- API specifications
- Architecture diagrams
- Component guides
- Integration instructions
- Deployment procedures

### Documentation Update Process

When updating documentation:

1. **Create Draft Version**: Save updated documentation with `.draft.md` suffix (e.g., `component-guide.draft.md`)

2. **Highlight Changes - Minimal Approach**:
   - **ONLY highlight the specific changed blocks** with green background
   - Keep unchanged content as-is (no highlighting)
   - Minimize the amount of highlighted text to only what actually changed

   ```markdown
   Existing unchanged paragraph stays normal.

   <div style="background-color: #d4edda; padding: 10px; border-radius: 5px;">

   This specific paragraph was updated or added.

   </div>

   Another unchanged paragraph stays normal.
   ```

3. **Mermaid Diagram Updates - Highlight Only Changed Elements**:
   - Keep the entire diagram visible for context
   - **Apply green styling ONLY to changed/new elements** within the diagram
   - Users must always see what changed in diagrams
   - Use Mermaid's `classDef` to highlight updated nodes, edges, or sections
   - **VITAL: Always validate Mermaid syntax before saving**:
     - Check for proper node definitions
     - Verify all arrows and connections are valid
     - Ensure class definitions are correctly applied
     - Test that the diagram renders without errors
     - Mermaid syntax errors will break the documentation

   ```markdown
   ```mermaid
   graph TD
       A[Unchanged Component] --> B[Updated Component]
       B --> C[New Component]
       B --> D[Unchanged Component]

       %% Highlight ONLY updated/new elements
       classDef updated fill:#d4edda,stroke:#28a745,stroke-width:3px
       classDef new fill:#d1ecf1,stroke:#17a2b8,stroke-width:3px

       class B updated
       class C new
   ```
   ```

4. **Review Process**: Draft files remain in the docs folder for review before approval

5. **Approval Process**: When user requests to approve documentation updates:
   - Replace the original file with the draft content (remove highlighting and Mermaid styling)
   - Delete the `.draft.md` file
   - Keep only the clean, approved version

### Example Workflow

```bash
# Creating a draft update
docs/api-guide.md → docs/api-guide.draft.md (with green highlights)

# After approval
docs/api-guide.draft.md → docs/api-guide.md (clean version)
# Delete docs/api-guide.draft.md
```

