import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About VelocityVer'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Section
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade100,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.deepPurple.shade300,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.school,
                        size: 50,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'VelocityVer',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Mission Section
              _buildSection(
                'Our Mission',
                'To eliminate internet dependency in educational environments by providing a robust offline-first file sharing system that keeps learning materials accessible anytime, anywhere within your institution.',
                Icons.flag,
                Colors.blue,
              ),

              // Features Section
              _buildSection(
                'Key Features',
                '• Offline-first architecture - works without internet\n'
                '• Real-time sync when connected to school network\n'
                '• Role-based access (Students, Lecturers, Admins)\n'
                '• Course-based file organization\n'
                '• Automatic server discovery\n'
                '• Secure file sharing and storage\n'
                '• Cross-platform compatibility',
                Icons.star,
                Colors.orange,
              ),

              // How It Works Section
              _buildSection(
                'How It Works',
                '1. Connect to your school\'s Wi-Fi network\n'
                '2. App automatically discovers the VelocityVer server\n'
                '3. Login with your credentials\n'
                '4. Access course materials based on your role\n'
                '5. Download files for offline access\n'
                '6. Changes sync automatically when connected',
                Icons.settings,
                Colors.green,
              ),

              // Benefits Section
              _buildSection(
                'Benefits',
                '• No internet required for file access\n'
                '• Faster file sharing within campus\n'
                '• Reduced data costs for students\n'
                '• Always-available course materials\n'
                '• Improved learning continuity\n'
                '• Enhanced educational experience',
                Icons.thumb_up,
                Colors.purple,
              ),

              const SizedBox(height: 32),

              // Footer
              Center(
                child: Column(
                  children: [
                    Text(
                      'Designed for Educational Excellence',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Making education accessible, offline-first',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
