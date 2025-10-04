# 🔑 VelocityVer Login Credentials

## ✅ **Fixed Issues**
- ✅ Password hashing mismatch between AuthService and DatabaseService **FIXED**
- ✅ Missing default users in database **FIXED**
- ✅ App now creates 4 default users for testing

## 🎯 **Default Login Credentials**

### **Super Admin** (Full System Access)
```
Username: superadmin
Password: admin123
```
- Can manage everything in the system
- Access to all admin functions
- User management, course management, system settings

### **Admin** (Administrative Access)
```
Username: admin
Password: admin123
```
- Can manage users and courses
- Access to admin dashboard
- Faculty and department management

### **Lecturer** (Course Management)
```
Username: lecturer
Password: lecturer123
```
- Can manage assigned courses
- Upload files to courses
- Create course announcements
- View enrolled students

### **Student** (Course Access)
```
Username: student
Password: student123
```
- Can view enrolled courses only
- Download course materials
- View announcements
- Access course details

## 🚀 **Testing Steps**

### **1. Install the App**
```bash
flutter install
# or manually install the APK from build/app/outputs/flutter-apk/
```

### **2. First Launch**
- App will show **Login Screen** (this is correct behavior)
- Database will be automatically created with default users
- No welcome screen needed - login directly

### **3. Test Each User Type**
1. **Login as Super Admin** (`superadmin` / `admin123`)
   - Should see Admin Dashboard with all management options
   - Test Server Settings, User Management, Course Registration

2. **Login as Admin** (`admin` / `admin123`)
   - Should see Admin Dashboard
   - Test Faculty Management, Department Management

3. **Login as Lecturer** (`lecturer` / `lecturer123`)
   - Should see Lecturer Dashboard
   - Test Course Management, File Upload

4. **Login as Student** (`student` / `student123`)
   - Should see Student Dashboard
   - Should only see enrolled courses (initially none)

### **4. Test Core Features**
- **User Management**: Create new users with different roles
- **Course Management**: Create courses and assign to departments
- **Course Registration**: Enroll students in courses
- **File Sharing**: Upload and download files
- **Server Settings**: Configure PC server connection

## 🔧 **If Login Still Fails**

### **Reset Database** (Nuclear Option)
```bash
# Run the reset script
reset_database.bat

# Or manually:
flutter clean
adb shell pm clear com.example.velocityver
flutter build apk --debug
flutter install
```

### **Check Database Creation**
The app should automatically:
1. Create SQLite database on first run
2. Insert 4 default users with hashed passwords
3. Create default academic structure (faculties, departments, etc.)

### **Debug Login Issues**
If credentials still don't work:
1. Check app logs for database errors
2. Verify database file is created
3. Check if password hashing is working correctly

## 📱 **Expected App Flow**

```
App Launch
    ↓
Login Screen (shows immediately)
    ↓
Enter Credentials
    ↓
Dashboard (based on user role)
    ↓
Access Features (based on permissions)
```

## 🎉 **Success Indicators**

You'll know it's working when:
- ✅ Login screen appears on app launch
- ✅ Default credentials work for all 4 users
- ✅ Each user sees appropriate dashboard
- ✅ Role-based features are accessible
- ✅ Database is populated with default data

The app is now ready for multi-device testing with your PC server! 🚀
