# Shopizer Backend - Startup Guide

This guide explains how to start and stop the Shopizer backend server using the provided scripts.

## Prerequisites

- Java 11 or higher (Java 21 recommended)
- Maven (included via Maven Wrapper - mvnw)

## Quick Start

### Mac / Linux

**Start the server:**
```bash
./start-backend.sh
```

**Stop the server:**
```bash
./stop-backend.sh
```

### Windows

**Option 1: Using Batch Script (CMD)**
- Double-click `start-backend.bat` or run from Command Prompt:
```cmd
start-backend.bat
```

- To stop: Double-click `stop-backend.bat` or run:
```cmd
stop-backend.bat
```

**Option 2: Using PowerShell**
```powershell
.\start-backend.ps1
```

- To stop:
```powershell
.\stop-backend.ps1
```

**Note:** You may need to enable script execution in PowerShell:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## What the Scripts Do

### Start Scripts
1. Check if Java is installed
2. Display Java version
3. Navigate to the `sm-shop` directory
4. Build and start the Spring Boot application
5. Initialize the database with sample data (on first run)

### Stop Scripts
1. Find running Shopizer server processes
2. Gracefully stop the server
3. Force kill if necessary

## Server Information

Once started, the server will be available at:

- **Base URL:** http://localhost:8080
- **API Documentation (Swagger):** http://localhost:8080/swagger-ui.html
- **Health Check:** http://localhost:8080/actuator/health

## Database Configuration

The server is configured to use **H2 in-memory database** by default for quick local development.

To use MySQL instead:
1. Edit `sm-shop/src/main/resources/database.properties`
2. Update the connection settings to point to your MySQL instance
3. Create the database as instructed in the comments

## Startup Time

- **First run:** 30-60 seconds (includes building and initializing database)
- **Subsequent runs:** 20-30 seconds

## Troubleshooting

### Port 8080 Already in Use
If you get a "port already in use" error:
1. Run the stop script to ensure no previous instance is running
2. Check if another application is using port 8080
3. Change the port in `sm-shop/src/main/resources/application.properties`

### Java Version Issues
Make sure you're using Java 11 or higher. Check your version:
```bash
java -version
```

### Build Errors
If you encounter build errors, try cleaning and rebuilding:
```bash
cd sm-shop
../mvnw clean install
```

## Manual Commands

If you prefer to run commands manually:

**Build the project:**
```bash
./mvnw clean install
```

**Start the server:**
```bash
cd sm-shop
../mvnw spring-boot:run
```

**Stop the server:**
Press `Ctrl+C` in the terminal where the server is running

## Default Credentials

The system initializes with a default merchant store. Check the logs or API documentation for default credentials and sample data.
