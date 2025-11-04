#!/bin/bash

# Shopizer Backend Startup Script for Mac/Linux
# This script starts the Shopizer e-commerce backend server

echo "======================================"
echo "Starting Shopizer Backend Server"
echo "======================================"
echo ""

# Check if Java 21 is available
if ! command -v java &> /dev/null; then
    echo "Error: Java is not installed or not in PATH"
    echo "Please install Java 21 or higher"
    exit 1
fi

JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
echo "Java version detected: $(java -version 2>&1 | head -n 1)"
echo ""

if [ "$JAVA_VERSION" -lt 11 ]; then
    echo "Warning: Java 11 or higher is recommended (Java 21 preferred)"
    echo ""
fi

# Build all modules first (required for multi-module project)
echo "Building project modules (skipping tests for faster startup)..."
echo "This may take a few moments on first run..."
echo ""

./mvnw clean install -DskipTests || exit 1

echo ""
echo "Build successful! Starting the server..."
echo ""

# Navigate to sm-shop directory and start the server
cd sm-shop || exit 1
../mvnw spring-boot:run -DskipTests

# If the server stops, show this message
echo ""
echo "======================================"
echo "Server has stopped"
echo "======================================"
