#!/usr/bin/env python3
"""
Simple test server to verify connectivity
"""

from flask import Flask, jsonify
from flask_cors import CORS
import socket

app = Flask(__name__)
CORS(app)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'message': 'Simple test server working!'})

@app.route('/test', methods=['GET'])
def test():
    return jsonify({'message': 'Test endpoint working!'})

if __name__ == '__main__':
    # Get local IP
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    
    print("=" * 50)
    print("🧪 Simple Test Server")
    print("=" * 50)
    print(f"Local:   http://localhost:5000/health")
    print(f"Network: http://{local_ip}:5000/health")
    print("=" * 50)
    
    app.run(host='0.0.0.0', port=5000, debug=False)
