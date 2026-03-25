# Multi-stage build
FROM maven:3.8.6-eclipse-temurin-11 AS builder

WORKDIR /app

# Copy pom files
COPY pom.xml .
COPY sm-core/pom.xml sm-core/
COPY sm-core-model/pom.xml sm-core-model/
COPY sm-core-modules/pom.xml sm-core-modules/
COPY sm-shop/pom.xml sm-shop/
COPY sm-shop-model/pom.xml sm-shop-model/

# Download dependencies
RUN mvn dependency:go-offline -B

# Copy source code
COPY sm-core sm-core
COPY sm-core-model sm-core-model
COPY sm-core-modules sm-core-modules
COPY sm-shop sm-shop
COPY sm-shop-model sm-shop-model

# Replace database.properties with Docker version
RUN cp sm-shop/src/main/resources/database-docker.properties sm-shop/src/main/resources/database.properties

# Build the application
RUN mvn clean package -DskipTests

# Runtime stage
FROM eclipse-temurin:11-jre

WORKDIR /app

# Copy the built jar from builder stage
COPY --from=builder /app/sm-shop/target/*.jar app.jar

# Expose port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
