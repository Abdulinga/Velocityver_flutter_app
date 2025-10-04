import 'package:flutter/material.dart';
import '../services/background_discovery_service.dart';

/// Widget that shows current server connection status (read-only)
class ServerStatusWidget extends StatefulWidget {
  const ServerStatusWidget({super.key});

  @override
  State<ServerStatusWidget> createState() => _ServerStatusWidgetState();
}

class _ServerStatusWidgetState extends State<ServerStatusWidget> {
  final BackgroundDiscoveryService _discoveryService =
      BackgroundDiscoveryService();
  Map<String, dynamic>? _serverStatus;

  @override
  void initState() {
    super.initState();
    _loadServerStatus();

    // Refresh status every 10 seconds
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _startStatusUpdates();
      }
    });
  }

  void _startStatusUpdates() {
    Stream.periodic(
      const Duration(seconds: 10),
    ).listen((_) => _loadServerStatus());
  }

  Future<void> _loadServerStatus() async {
    try {
      final status = await _discoveryService.getServerStatus();
      if (mounted) {
        setState(() {
          _serverStatus = status;
        });
      }
    } catch (e) {
      debugPrint('Error loading server status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_serverStatus == null) {
      return const SizedBox.shrink();
    }

    final isConnected = _serverStatus!['connected'] as bool;
    final serverUrl = _serverStatus!['serverUrl'] as String?;

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.cloud_done : Icons.cloud_off,
            size: 16,
            color: isConnected ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Connected' : 'Connecting...',
            style: TextStyle(
              fontSize: 12,
              color: isConnected
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (serverUrl != null && isConnected) ...[
            const SizedBox(width: 4),
            Text(
              '(${Uri.parse(serverUrl).host})',
              style: TextStyle(fontSize: 10, color: Colors.green.shade600),
            ),
          ],
        ],
      ),
    );
  }
}
