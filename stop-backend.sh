#!/bin/bash

# Shopizer Backend Stop Script for Mac/Linux
# This script stops the running Shopizer backend server

echo "======================================"
echo "Stopping Shopizer Backend Server"
echo "======================================"
echo ""

# Find and kill the Java process running Shopizer
SHOPIZER_PID=$(ps aux | grep '[s]m-shop.*spring-boot:run' | awk '{print $2}')

if [ -z "$SHOPIZER_PID" ]; then
    echo "No running Shopizer server found."
    echo ""
else
    echo "Found Shopizer server running with PID: $SHOPIZER_PID"
    echo "Stopping server..."
    kill $SHOPIZER_PID
    sleep 2

    # Check if process is still running
    if ps -p $SHOPIZER_PID > /dev/null 2>&1; then
        echo "Server did not stop gracefully, forcing shutdown..."
        kill -9 $SHOPIZER_PID
    fi

    echo "Server stopped successfully."
    echo ""
fi

echo "======================================"
echo "Done"
echo "======================================"
