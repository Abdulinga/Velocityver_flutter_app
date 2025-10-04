import 'package:http/http.dart' as http;

/// Simple test to verify hardcoded server connection
Future<void> main() async {
  const serverUrl = 'http://192.168.1.155:5000';
  
  print('🔍 Testing hardcoded server connection...');
  print('📡 Server URL: $serverUrl');
  
  try {
    // Test health endpoint
    print('🔌 Testing health endpoint...');
    final healthResponse = await http.get(
      Uri.parse('$serverUrl/health'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 5));
    
    print('📡 Health response: ${healthResponse.statusCode}');
    if (healthResponse.statusCode == 200) {
      print('✅ Health check passed!');
      print('📄 Response: ${healthResponse.body}');
    } else {
      print('❌ Health check failed: ${healthResponse.statusCode}');
    }
    
    // Test API endpoints
    final endpoints = ['/api/users', '/api/roles', '/api/courses'];
    
    for (final endpoint in endpoints) {
      print('🔌 Testing $endpoint...');
      try {
        final response = await http.get(
          Uri.parse('$serverUrl$endpoint'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          print('✅ $endpoint: OK');
        } else {
          print('⚠️ $endpoint: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ $endpoint: $e');
      }
    }
    
  } catch (e) {
    print('❌ Connection test failed: $e');
    print('');
    print('🔧 Troubleshooting:');
    print('1. Make sure server is running: python app.py');
    print('2. Check server IP in startup logs');
    print('3. Verify both devices on same Wi-Fi');
    print('4. Test in browser: $serverUrl/health');
  }
  
  print('');
  print('🎯 Test complete!');
}
