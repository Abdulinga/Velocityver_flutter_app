#!/bin/bash

echo "========================================"
echo "    VelocityVer Server Startup"
echo "========================================"
echo

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed"
    echo "Please install Python 3.7+ from your package manager"
    exit 1
fi

echo "Python found. Checking dependencies..."

# Install required packages if not present
pip3 install flask flask-cors werkzeug

echo
echo "Starting VelocityVer Server..."
echo
echo "IMPORTANT: Make sure firewall allows Python/Flask"
echo "           or configure firewall rules for port 5000"
echo

# Start the Flask server
python3 app.py
