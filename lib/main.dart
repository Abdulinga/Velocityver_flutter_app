import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/services.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('🚀 Starting VelocityVer initialization...');

    // Initialize core services in proper dependency order
    final initializedServices = await _initializeCoreServices();
    
    print('✅ All services initialized successfully');
    print('🚀 Starting VelocityVer app...');

    runApp(
      VelocityVerApp(
        authService: initializedServices.authService,
        connectivityService: initializedServices.connectivityService,
        databaseService: initializedServices.databaseService,
      ),
    );
  } catch (e, stackTrace) {
    print('❌ Critical initialization failure: $e');
    print('Stack trace: $stackTrace');
    
    // Show error recovery app
    runApp(_buildErrorRecoveryApp(e));
  }
}

/// Container for initialized services
class _InitializedServices {
  final DatabaseService databaseService;
  final AuthService authService;
  final ConnectivityService connectivityService;

  const _InitializedServices({
    required this.databaseService,
    required this.authService,
    required this.connectivityService,
  });
}

/// Initialize all core services in proper dependency order
Future<_InitializedServices> _initializeCoreServices() async {
  // Step 1: Initialize database service (foundation for other services)
  print('🔄 [1/5] Initializing database service...');
  final databaseService = DatabaseService();
  await databaseService.database; // Trigger database creation and seeding
  print('✅ Database service initialized');

  // Step 2: Initialize auth service (depends on database)
  print('🔄 [2/5] Initializing auth service...');
  final authService = AuthService();
  await authService.initialize();
  print('✅ Auth service initialized');

  // Step 3: Initialize connectivity service (independent)
  print('🔄 [3/5] Initializing connectivity service...');
  final connectivityService = ConnectivityService();
  await connectivityService.initialize();
  print('✅ Connectivity service initialized');

  // Step 4: Initialize sync service (depends on auth and connectivity)
  print('🔄 [4/5] Initializing sync service...');
  await SyncService.initialize();
  print('✅ Sync service initialized');

  // Step 5: Initialize background discovery service (optional, non-blocking)
  print('🔄 [5/5] Initializing background discovery service...');
  try {
    final backgroundDiscovery = BackgroundDiscoveryService();
    await backgroundDiscovery.initialize();
    print('✅ Background discovery service initialized');
  } catch (e) {
    print('⚠️ Background discovery service failed to initialize: $e');
    // Continue without background discovery - it's not critical
  }

  return _InitializedServices(
    databaseService: databaseService,
    authService: authService,
    connectivityService: connectivityService,
  );
}

/// Build error recovery app when critical initialization fails
Widget _buildErrorRecoveryApp(dynamic error) {
  return MaterialApp(
    title: 'VelocityVer - Error',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      useMaterial3: true,
    ),
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                const Text(
                  'VelocityVer',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to Initialize',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    'Error: $error',
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        // Restart the app
                        main();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Could implement diagnostic mode or safe mode
                        _showDiagnosticDialog();
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    debugShowCheckedModeBanner: false,
  );
}

/// Show diagnostic information (placeholder for future implementation)
void _showDiagnosticDialog() {
  // Future implementation could show:
  // - System info
  // - Storage permissions
  // - Network status
  // - Debug logs
  print('🔍 Diagnostic information requested');
}

class VelocityVerApp extends StatefulWidget {
  final AuthService authService;
  final ConnectivityService connectivityService;
  final DatabaseService databaseService;

  const VelocityVerApp({
    super.key,
    required this.authService,
    required this.connectivityService,
    required this.databaseService,
  });

  @override
  State<VelocityVerApp> createState() => _VelocityVerAppState();
}

class _VelocityVerAppState extends State<VelocityVerApp> {
  bool _isAppReady = false;
  String _initializationStatus = 'Preparing application...';
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    _finalizeAppInitialization();
  }

  /// Perform final app-level initialization steps
  Future<void> _finalizeAppInitialization() async {
    try {
      await _performInitializationSteps();
      
      setState(() {
        _isAppReady = true;
        _initializationStatus = 'Application ready!';
      });
    } catch (e) {
      setState(() {
        _initializationError = e.toString();
        _initializationStatus = 'Initialization failed';
      });
      print('❌ App finalization error: $e');
    }
  }

  /// Perform step-by-step app initialization with status updates
  Future<void> _performInitializationSteps() async {
    // Step 1: Verify database connectivity
    await _updateStatusAndWait('Verifying database connection...');
    await widget.databaseService.database;

    // Step 2: Validate user session
    await _updateStatusAndWait('Validating user session...');
    if (widget.authService.isLoggedIn) {
      await widget.authService.refreshCurrentUser();
    }

    // Step 3: Check system readiness
    await _updateStatusAndWait('Finalizing setup...');
    await Future.delayed(const Duration(milliseconds: 300)); // Brief pause for UI

    // Step 4: Complete
    await _updateStatusAndWait('Ready!');
  }

  /// Update status message and allow UI to refresh
  Future<void> _updateStatusAndWait(String status) async {
    setState(() => _initializationStatus = status);
    await Future.delayed(const Duration(milliseconds: 200)); // Allow UI update
  }

  /// Retry initialization after failure
  Future<void> _retryInitialization() async {
    setState(() {
      _isAppReady = false;
      _initializationError = null;
      _initializationStatus = 'Retrying initialization...';
    });
    
    await _finalizeAppInitialization();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.connectivityService),
        // Additional providers can be added here as needed
      ],
      child: MaterialApp(
        title: 'VelocityVer',
        theme: _buildAppTheme(),
        home: _buildAppHome(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  /// Build the main application theme
  ThemeData _buildAppTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  /// Build the appropriate home screen based on app state
  Widget _buildAppHome() {
    if (!_isAppReady) {
      return _buildInitializationScreen();
    }

    // Navigate to appropriate screen based on authentication status
    return widget.authService.isLoggedIn
        ? const DashboardScreen()
        : const WelcomeScreen();
  }

  /// Build the initialization loading screen
  Widget _buildInitializationScreen() {
    final hasError = _initializationError != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App branding
                _buildAppBranding(),
                const SizedBox(height: 32),
                
                // Loading indicator or error icon
                if (hasError)
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.orange,
                  )
                else
                  const CircularProgressIndicator(),
                
                const SizedBox(height: 24),
                
                // Status text
                Text(
                  _initializationStatus,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                
                // Error details and retry button
                if (hasError) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      _initializationError!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _retryInitialization,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build app branding section
  Widget _buildAppBranding() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.speed,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'VelocityVer',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Learning Management System',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}