# 📱 VelocityVer Installation Guide

## ✅ **What's Fixed**

- ✅ **Pre-built Database**: Created SQLite database with all default data
- ✅ **Asset Integration**: Database is bundled with the app
- ✅ **Reliable Login**: All 4 default users work consistently
- ✅ **Release Build**: Uses stable release build instead of debug

## 🗄️ **Database Solution**

Instead of creating the database at runtime (which was causing issues), the app now:

1. **Includes a pre-built database** in `assets/velocityver.db`
2. **Copies database on first run** from assets to app storage
3. **Contains all default data** (users, roles, academic structure)
4. **Uses consistent password hashing** across all components

## 🔑 **Login Credentials**

| Role | Username | Password | Access Level |
|------|----------|----------|--------------|
| **Super Admin** | `superadmin` | `admin123` | Full system access |
| **Admin** | `admin` | `admin123` | User & course management |
| **Lecturer** | `lecturer` | `lecturer123` | Course management |
| **Student** | `student` | `student123` | Course access only |

## 🚀 **Installation Steps**

### **1. Build & Install App**
```bash
# Build release APK (more stable than debug)
flutter build apk --release

# Install on connected device
flutter install

# Or manually install APK
# Location: build/app/outputs/flutter-apk/app-release.apk
```

### **2. First Launch**
- App opens to **Login Screen** (correct behavior)
- Database is automatically copied from assets
- All 4 users are immediately available

### **3. Test Login**
Try logging in with any of the credentials above:
- **Super Admin**: Full access to all features
- **Admin**: User management, course management
- **Lecturer**: Course files, student management
- **Student**: View courses, download files

### **4. Start PC Server**
```bash
cd server
start_server.bat  # Windows
# or
./start_server.sh  # Linux/Mac
```

### **5. Configure Server Connection**
1. Login as admin/superadmin
2. Go to **Admin Dashboard → Server Settings**
3. Enter your PC's IP address (shown by server)
4. Test connection
5. Save settings

## 🔧 **Troubleshooting**

### **If Login Still Fails**
```bash
# Uninstall completely
adb uninstall com.example.velocityver

# Clean and rebuild
flutter clean
flutter build apk --release
flutter install
```

### **Check Database**
```bash
# Run database checker
check_database.bat

# Check app logs
adb logcat | findstr VelocityVer
```

### **Verify Database Creation**
The app should show these logs on first run:
```
🗄️ Database path: /data/data/com.example.velocityver/databases/velocityver.db
📋 Database not found, copying from assets...
✅ Database copied from assets successfully
```

## 📁 **File Structure**

```
velocityver/
├── assets/
│   └── velocityver.db          # Pre-built database
├── server/
│   ├── app.py                  # Flask server
│   ├── start_server.bat        # Windows startup
│   └── start_server.sh         # Linux/Mac startup
├── build/app/outputs/flutter-apk/
│   └── app-release.apk         # Final APK
└── lib/
    └── services/
        └── database_service.dart # Handles database copying
```

## 🎯 **Expected Behavior**

### **✅ Success Indicators**
- Login screen appears immediately
- All 4 default users can login
- Each user sees role-appropriate dashboard
- Database file exists in app storage
- Server connection works from app

### **❌ If Something's Wrong**
- Login fails → Check database copying logs
- No dashboard → Check user role assignment
- Server connection fails → Check PC firewall/IP

## 🌐 **Multi-Device Testing**

1. **Install APK on multiple devices**
2. **Connect all to same WiFi**
3. **Configure same server IP on all devices**
4. **Test file sharing between devices**
5. **Verify offline functionality**

## 🎉 **Ready for Testing!**

Your offline-first file-sharing system is now ready with:
- ✅ Reliable database initialization
- ✅ Consistent login credentials
- ✅ Role-based access control
- ✅ Multi-device sync capabilities
- ✅ Offline-first architecture

The pre-built database approach ensures consistent behavior across all devices! 🚀
