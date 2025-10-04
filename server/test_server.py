#!/usr/bin/env python3
"""
Quick test script to verify server starts without errors
"""

import sys
import os

# Add the server directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_server_import():
    """Test if the server can be imported without errors"""
    try:
        print("🔄 Testing server import...")
        import app
        print("✅ Server imports successfully!")
        return True
    except Exception as e:
        print(f"❌ Server import failed: {e}")
        return False

def test_flask_app():
    """Test if Flask app can be created"""
    try:
        print("🔄 Testing Flask app creation...")
        import app
        flask_app = app.app
        print(f"✅ Flask app created successfully!")
        print(f"📋 Registered routes:")
        
        # List all routes
        for rule in flask_app.url_map.iter_rules():
            methods = ','.join(rule.methods - {'HEAD', 'OPTIONS'})
            print(f"   {methods:10} {rule.rule}")
        
        return True
    except Exception as e:
        print(f"❌ Flask app creation failed: {e}")
        return False

def main():
    print("=" * 60)
    print("🧪 VelocityVer Server Test")
    print("=" * 60)
    
    success = True
    
    # Test 1: Import
    if not test_server_import():
        success = False
    
    print()
    
    # Test 2: Flask app
    if not test_flask_app():
        success = False
    
    print()
    print("=" * 60)
    if success:
        print("🎉 All tests passed! Server should start correctly.")
    else:
        print("💥 Some tests failed! Check the errors above.")
    print("=" * 60)
    
    return 0 if success else 1

if __name__ == '__main__':
    sys.exit(main())
