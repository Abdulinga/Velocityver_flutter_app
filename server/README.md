# VelocityVer Flask Server

This is the Flask server component of the VelocityVer offline-first file-sharing system.

## Setup

1. Install Python 3.8 or higher
2. Create a virtual environment:
   ```bash
   python -m venv venv
   ```

3. Activate the virtual environment:
   - Windows: `venv\Scripts\activate`
   - macOS/Linux: `source venv/bin/activate`

4. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

5. Run the server:
   ```bash
   python app.py
   ```

The server will start on `http://0.0.0.0:5000` and will be accessible from other devices on the local network.

## Default Credentials

- **Username**: superadmin
- **Password**: admin123

## API Endpoints

### Authentication
- `POST /api/auth/login` - User login

### Users
- `GET /api/users` - Get all users
- `POST /api/users` - Create new user
- `PUT /api/users/<id>` - Update user

### Courses
- `GET /api/courses` - Get all courses
- `POST /api/courses` - Create new course

### Files
- `GET /api/files` - Get all files
- `POST /api/files/upload` - Upload file
- `GET /api/files/<id>/download` - Download file

### Announcements
- `GET /api/announcements` - Get all announcements
- `POST /api/announcements` - Create announcement

### Health Check
- `GET /health` - Server health check

## Database

The server uses SQLite database (`velocityver_server.db`) which will be created automatically on first run.

## File Storage

Uploaded files are stored in the `uploads/` directory, organized by course ID.

## Network Configuration

Make sure your local network allows connections on port 5000. Update the Flutter app's sync service to use your server's IP address (replace `192.168.1.100` with your actual IP).
