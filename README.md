# VelocityVer - Offline-First File Sharing System

A comprehensive offline-first file-sharing system built with Flutter and Python Flask, designed for educational institutions with role-based access control.

VelocityVer is an offline-first file-sharing system designed for educational institutions. 
It provides role-based access for students, lecturers, admins, and super admins, enabling 
course management, announcements, and file sharing even without internet connectivity. 
The system automatically syncs with a Flask server when online.

## Features

### 🔐 Role-Based Access Control
- **Student**: View courses, download files, view announcements, profile management
- **Lecturer**: Manage assigned courses, upload/edit files, create announcements
- **Admin**: User management, course management, system announcements, role assignments
- **Super Admin**: Full system access, database management, system monitoring

### 📱 Offline-First Architecture
- Local SQLite database for offline functionality
- Automatic sync when network is available
- File caching for offline access
- Conflict resolution for data synchronization

### 🌐 Network Sync
- Bidirectional sync with Flask server
- File upload/download over local Wi-Fi
- Metadata synchronization
- Network status monitoring

### 📁 File Management
- Course-based file organization
- Multiple file format support (PDF, DOC, images, etc.)
- File preview and download
- Storage management and cleanup

## Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │◄──►│  Flask Server   │
│                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │   SQLite    │ │    │ │   SQLite    │ │
│ │  (Local)    │ │    │ │  (Server)   │ │
│ └─────────────┘ │    │ └─────────────┘ │
│                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Local Files │ │    │ │Server Files │ │
│ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘
```

## Quick Start

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Python 3.8 or higher
- Android Studio / VS Code
- Git

### 1. Clone the Repository
```bash
git clone <repository-url>
cd velocityver
```

### 2. Setup Flutter App
```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
```

### 3. Setup Flask Server
```bash
# Navigate to server directory
cd server

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run server
python app.py
```

### 4. Network Configuration
1. Find your computer's IP address on the local network
2. Update `lib/services/sync_service.dart`:
   ```dart
   static const String baseUrl = 'http://YOUR_IP_ADDRESS:5000';
   ```
3. Ensure devices are on the same Wi-Fi network

## Default Credentials

**Super Admin Account:**
- Username: `superadmin`
- Password: `admin123`

## Project Structure

```
velocityver/
├── lib/
│   ├── models/          # Data models
│   ├── services/        # Business logic services
│   ├── screens/         # UI screens
│   ├── widgets/         # Reusable widgets
│   ├── utils/           # Utility classes
│   └── main.dart        # App entry point
├── server/
│   ├── app.py           # Flask server
│   ├── requirements.txt # Python dependencies
│   └── README.md        # Server setup guide
└── README.md            # This file
```

## Key Components

### Services
- **DatabaseService**: Local SQLite operations
- **AuthService**: Authentication and authorization
- **FileService**: File management and storage
- **SyncService**: Data synchronization
- **ConnectivityService**: Network monitoring

### Models
- **User**: User accounts with roles
- **Course**: Academic courses
- **FileModel**: File metadata and storage
- **Announcement**: System announcements
- **SyncMetadata**: Sync tracking

### Screens
- **LoginScreen**: User authentication
- **DashboardScreen**: Role-based routing
- **StudentDashboard**: Student interface
- **LecturerDashboard**: Lecturer interface
- **AdminDashboard**: Admin interface
- **SuperAdminDashboard**: System management

## Development

### Adding New Features
1. Create models in `lib/models/`
2. Add database operations in `lib/services/database_service.dart`
3. Implement business logic in appropriate services
4. Create UI components in `lib/screens/` and `lib/widgets/`
5. Add server endpoints in `server/app.py`

### Testing
```bash
# Run Flutter tests
flutter test

# Run widget tests
flutter test test/widget_test.dart
```

## Deployment

### Flutter App
```bash
# Build APK
flutter build apk

# Build iOS (macOS only)
flutter build ios
```

### Flask Server
```bash
# For production, use a proper WSGI server
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 app:app
```

## Troubleshooting

### Common Issues

1. **Sync not working**: Check network connectivity and server IP address
2. **Files not uploading**: Verify file permissions and storage space
3. **Login issues**: Ensure database is initialized with default users
4. **Build errors**: Run `flutter clean` and `flutter pub get`

### Debug Mode
The app includes comprehensive logging. Check console output for detailed error messages.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions, please create an issue in the repository.
