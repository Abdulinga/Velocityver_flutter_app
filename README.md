
# **VelocityVer - Offline-First File Sharing System**

A cross-platform **offline-first file-sharing system** built with **Flutter** and **Python Flask**, designed for educational institutions with **role-based access control**.

> ⚡ VelocityVer allows students, lecturers, admins, and super admins to manage courses, share files, and make announcements even **without internet connectivity**. All changes are synced automatically when the network is available.

---

## 🚀 Features

### 🔐 Role-Based Access Control

* **Student**: View courses, download files, view announcements, manage profile.
* **Lecturer**: Manage assigned courses, upload/edit files, create announcements.
* **Admin**: Manage users, courses, announcements, and role assignments.
* **Super Admin**: Full system control, database management, monitoring.

### 📱 Offline-First Architecture

* Local **SQLite database** for offline usage.
* Automatic sync when online.
* File caching for offline access.
* Conflict resolution during sync.

### 🌐 Network Sync

* Bidirectional sync with Flask server.
* File upload/download over local Wi-Fi.
* Metadata synchronization.
* Real-time network status monitoring.

### 📁 File Management

* Course-based file organization.
* Multiple file format support (PDF, DOC, images, etc.).
* File preview & download.
* Storage management and cleanup.

---

## 🖼 Screenshots

(Add your app screenshots here after you capture them)

Example:

```
assets/screenshots/login.png  
assets/screenshots/dashboard.png  
assets/screenshots/files.png  
```

```markdown
![Login Screen](assets/screenshots/login.png)  
![Dashboard](assets/screenshots/dashboard.png)  
![File Management](assets/screenshots/files.png)  
```

---

## 🏗 Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │◄──►│  Flask Server   │
│                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │   SQLite    │ │    │ │   SQLite    │ │
│ │  (Local)    │ │    │ │  (Server)   │ │
│ └─────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Local Files │ │    │ │ Server Files│ │
│ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘
```

---

## ⚙️ Quick Start

### Prerequisites

* Flutter SDK (3.8.1+)
* Python 3.8+
* Android Studio / VS Code
* Git

### 1. Clone the Repository

```bash
git clone https://github.com/Abdulinga/Velocityver_flutter_app.git
cd velocityver
```

### 2. Setup Flutter App

```bash
flutter pub get
flutter run
```

### 3. Setup Flask Server

```bash
cd server
python -m venv venv
venv\Scripts\activate   # Windows
source venv/bin/activate  # macOS/Linux
pip install -r requirements.txt
python app.py
```

### 4. Network Configuration

Update `lib/services/sync_service.dart`:

```dart
static const String baseUrl = 'http://YOUR_IP_ADDRESS:5000';
```

---

## 🗂 Project Structure

```
velocityver/
├── lib/          # Flutter app code
├── server/       # Flask backend
├── assets/       # App resources (add screenshots here)
├── android/      # Android-specific files
├── ios/          # iOS-specific files
└── README.md     # This file
```

---

## 👨‍💻 Development Notes

* Add models in `lib/models/`
* Add services in `lib/services/`
* Add UI screens in `lib/screens/`
* Add endpoints in `server/app.py`

Run tests:

```bash
flutter test
```

---

## 🛠 Troubleshooting

* **Sync not working:** Check network & IP address.
* **Files not uploading:** Verify permissions & storage.
* **Login issues:** Ensure database is initialized with default users.
* **Build errors:** Run `flutter clean && flutter pub get`.

---

## 📜 License

This project is licensed under the **MIT License**.

