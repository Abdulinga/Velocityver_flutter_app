import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

import '../services/services.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isConnectingToServer = true;
  String _connectionStatus = 'Connecting to server...';
  bool _obscurePassword = true;
  int _secretTapCount = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill for testing
    _usernameController.text = 'student';
    _passwordController.text = 'student123';

    // Start server connection when login screen loads
    _connectToServer();
  }

  Future<void> _connectToServer() async {
    setState(() {
      _isConnectingToServer = true;
      _connectionStatus = 'Connecting to server...';
    });

    try {
      debugPrint('🔍 Starting direct server connection...');

      // Try multiple direct requests to force connection
      final testUrls = [
        'http://192.168.1.155:5000/health',
        'http://192.168.1.155:5000/api/test',
        'http://192.168.1.155:5000/api/roles',
      ];

      bool connected = false;

      for (final url in testUrls) {
        setState(() {
          _connectionStatus = 'Testing $url...';
        });

        debugPrint('🎯 Direct HTTP GET to: $url');

        try {
          final response = await http
              .get(
                Uri.parse(url),
                headers: {'Content-Type': 'application/json'},
              )
              .timeout(const Duration(seconds: 5));

          debugPrint('📡 Response from $url: ${response.statusCode}');
          debugPrint('📄 Response body: ${response.body}');

          if (response.statusCode == 200) {
            connected = true;
            debugPrint('✅ SUCCESS: Server responded from $url');
            break;
          }
        } catch (e) {
          debugPrint('❌ Failed to connect to $url: $e');
        }

        // Small delay between attempts
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (connected) {
        setState(() {
          _isConnectingToServer = false;
          _connectionStatus = 'Connected to server';
        });
        debugPrint('🎉 Server connection established!');

        // Save the working server URL
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('server_url', 'http://192.168.1.155:5000');
      } else {
        setState(() {
          _isConnectingToServer = false;
          _connectionStatus = 'Using offline mode';
        });
        debugPrint('❌ All connection attempts failed');
      }
    } catch (e) {
      setState(() {
        _isConnectingToServer = false;
        _connectionStatus = 'Using offline mode';
      });
      debugPrint('❌ Server connection error: $e');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      final success = await authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (success) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid username or password';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleSecretTap() {
    setState(() {
      _secretTapCount++;
    });

    // Reset counter after 3 seconds of inactivity
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _secretTapCount = 0;
        });
      }
    });

    // Secret sequence: 7 taps to enable super admin mode
    if (_secretTapCount >= 7) {
      setState(() {
        _secretTapCount = 0;
        _usernameController.text = 'superadmin';
        _passwordController.text = 'admin123';
      });

      // Show secret access notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.security, color: Colors.white),
              SizedBox(width: 8),
              Text('Super Admin access enabled'),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (_secretTapCount >= 5) {
      // Give a hint after 5 taps
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${7 - _secretTapCount} more taps...'),
          backgroundColor: Colors.orange,
          duration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo/Title (with secret super admin access)
                GestureDetector(
                  onTap: _handleSecretTap,
                  child: const Icon(
                    Icons.school,
                    size: 80,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'VelocityVer',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'File Sharing System',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Username field
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 24),

                // Connection status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isConnectingToServer
                        ? Colors.blue[50]
                        : (_connectionStatus.contains('Connected')
                              ? Colors.green[50]
                              : Colors.orange[50]),
                    border: Border.all(
                      color: _isConnectingToServer
                          ? Colors.blue[300]!
                          : (_connectionStatus.contains('Connected')
                                ? Colors.green[300]!
                                : Colors.orange[300]!),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (_isConnectingToServer)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue[700]!,
                            ),
                          ),
                        )
                      else
                        Icon(
                          _connectionStatus.contains('Connected')
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                          color: _connectionStatus.contains('Connected')
                              ? Colors.green[700]
                              : Colors.orange[700],
                          size: 20,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _connectionStatus,
                          style: TextStyle(
                            color: _isConnectingToServer
                                ? Colors.blue[700]
                                : (_connectionStatus.contains('Connected')
                                      ? Colors.green[700]
                                      : Colors.orange[700]),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_errorMessage != null) const SizedBox(height: 16),

                // Login button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 24),

                // Network status indicator
                Consumer<ConnectivityService>(
                  builder: (context, connectivity, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: connectivity.isOnline
                            ? Colors.green[50]
                            : Colors.orange[50],
                        border: Border.all(
                          color: connectivity.isOnline
                              ? Colors.green[300]!
                              : Colors.orange[300]!,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            connectivity.isOnline ? Icons.wifi : Icons.wifi_off,
                            color: connectivity.isOnline
                                ? Colors.green[700]
                                : Colors.orange[700],
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            connectivity.isOnline ? 'Online' : 'Offline Mode',
                            style: TextStyle(
                              color: connectivity.isOnline
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Default credentials info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue[700], size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Default Credentials',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Student: student/student123\nLecturer: lecturer/lecturer123\nAdmin: admin/admin123',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
