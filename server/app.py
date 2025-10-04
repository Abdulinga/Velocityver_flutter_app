from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import sqlite3
import os
import hashlib
import uuid
import time
from datetime import datetime
import json
from werkzeug.utils import secure_filename
from werkzeug.security import generate_password_hash, check_password_hash
from flask import send_from_directory
import uuid
from datetime import datetime

app = Flask(__name__)
CORS(app)

# Configuration
DATABASE_PATH = 'velocityver.db'
UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'txt', 'pdf', 'png', 'jpg', 'jpeg', 'gif', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'}

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Ensure upload directory exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def get_db_connection():
    conn = sqlite3.connect(DATABASE_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_database():
    """Initialize the database with tables and default data (only if needed)"""
    conn = get_db_connection()

    # Check if database already has data
    try:
        user_count = conn.execute('SELECT COUNT(*) FROM users').fetchone()[0]
        if user_count > 0:
            print(f"✅ Database already initialized with {user_count} users")
            conn.close()
            return
    except sqlite3.OperationalError:
        # Tables don't exist yet, continue with initialization
        print("🔄 Database tables don't exist, creating them...")
        pass
    
    # Create tables (same structure as Flutter app)
    conn.execute('''
        CREATE TABLE IF NOT EXISTS roles (
            id TEXT PRIMARY KEY,
            name TEXT UNIQUE NOT NULL,
            description TEXT,
            permissions TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT
        )
    ''')
    
    conn.execute('''
        CREATE TABLE IF NOT EXISTS faculties (
            id TEXT PRIMARY KEY,
            name TEXT UNIQUE NOT NULL,
            description TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT
        )
    ''')
    
    conn.execute('''
        CREATE TABLE IF NOT EXISTS departments (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            faculty_id TEXT NOT NULL,
            description TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT,
            FOREIGN KEY (faculty_id) REFERENCES faculties (id)
        )
    ''')
    
    conn.execute('''
        CREATE TABLE IF NOT EXISTS levels (
            id TEXT PRIMARY KEY,
            name TEXT UNIQUE NOT NULL,
            description TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT
        )
    ''')
    
    conn.execute('''
        CREATE TABLE IF NOT EXISTS years (
            id TEXT PRIMARY KEY,
            name TEXT UNIQUE NOT NULL,
            description TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT
        )
    ''')
    conn.execute('''
    CREATE TABLE IF NOT EXISTS enrollments (
    id TEXT PRIMARY KEY,
    student_id TEXT NOT NULL,
    course_id TEXT NOT NULL,
    enrolled_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES users(id),
    FOREIGN KEY (course_id) REFERENCES courses(id)
);
''')
    
    conn.execute('''
    -- Seed enrollments for student users only
INSERT INTO enrollments (id, student_id, course_id, enrolled_at) VALUES
  ('enroll_1', 'user_student', 'course_cs_101', CURRENT_TIMESTAMP),
  ('enroll_2', 'user_student_cs_1', 'course_cs_101', CURRENT_TIMESTAMP),
  ('enroll_3', 'user_student_cs_2', 'course_cs_102', CURRENT_TIMESTAMP),
  ('enroll_4', 'user_student_ee_1', 'course_ee_101', CURRENT_TIMESTAMP),
  ('enroll_5', 'user_student_math_1', 'course_math_101', CURRENT_TIMESTAMP);
''')
    conn.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role_id TEXT NOT NULL,
            first_name TEXT NOT NULL,
            last_name TEXT NOT NULL,
            level_id TEXT,
            year_id TEXT,
            department_id TEXT,
            faculty_id TEXT,
            profile_picture TEXT,
            is_active INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT,
            FOREIGN KEY (role_id) REFERENCES roles (id)
        )
    ''')

    # Add profile_picture column if it doesn't exist (for existing databases)
    try:
        conn.execute('ALTER TABLE users ADD COLUMN profile_picture TEXT')
    except sqlite3.OperationalError:
        # Column already exists
        pass
    
    conn.execute('''
        CREATE TABLE IF NOT EXISTS courses (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT UNIQUE NOT NULL,
            description TEXT,
            level_id TEXT NOT NULL,
            year_id TEXT NOT NULL,
            department_id TEXT NOT NULL,
            faculty_id TEXT NOT NULL,
            lecturer_id TEXT,
            is_active INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT,
            FOREIGN KEY (lecturer_id) REFERENCES users (id)
        )
    ''')
    
    conn.execute('''
        CREATE TABLE IF NOT EXISTS files (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            original_name TEXT NOT NULL,
            file_path TEXT NOT NULL,
            file_size INTEGER NOT NULL,
            mime_type TEXT NOT NULL,
            course_id TEXT NOT NULL,
            uploaded_by TEXT NOT NULL,
            description TEXT,
            is_synced INTEGER DEFAULT 1,
            local_path TEXT,
            server_path TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT,
            FOREIGN KEY (course_id) REFERENCES courses (id),
            FOREIGN KEY (uploaded_by) REFERENCES users (id)
        )
    ''')
    
    conn.execute('''
        CREATE TABLE IF NOT EXISTS announcements (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            author_id TEXT NOT NULL,
            target_roles TEXT,
            target_courses TEXT,
            is_active INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT,
            FOREIGN KEY (author_id) REFERENCES users (id)
        )
    ''')

    # Chat system for admin-lecturer communication
    conn.execute('''
        CREATE TABLE IF NOT EXISTS messages (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            receiver_id TEXT,
            chat_room_id TEXT,
            message_type TEXT DEFAULT 'text',
            file_id TEXT,
            file_name TEXT,
            file_url TEXT,
            is_read INTEGER DEFAULT 0,
            is_delivered INTEGER DEFAULT 0,
            read_at TEXT,
            delivered_at TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT,
            FOREIGN KEY (sender_id) REFERENCES users (id),
            FOREIGN KEY (receiver_id) REFERENCES users (id),
            FOREIGN KEY (chat_room_id) REFERENCES chat_rooms (id)
        )
    ''')

    conn.execute('''
        CREATE TABLE IF NOT EXISTS chat_rooms (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_by TEXT NOT NULL, -- user_id of creator (admin or lecturer)
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
''')
    conn.execute('''CREATE TABLE IF NOT EXISTS chat_participants (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    joined_at TEXT NOT NULL,
    FOREIGN KEY (room_id) REFERENCES chat_rooms(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);
''')
    conn.execute('''CREATE TABLE IF NOT EXISTS chat_messages (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    sender_id TEXT NOT NULL,
    message TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (room_id) REFERENCES chat_rooms(id),
    FOREIGN KEY (sender_id) REFERENCES users(id)
);

    ''')

    # Student enrollment requests from lecturers to admins
    conn.execute('''
        CREATE TABLE IF NOT EXISTS enrollment_requests (
            id TEXT PRIMARY KEY,
            lecturer_id TEXT NOT NULL,
            course_id TEXT NOT NULL,
            student_ids TEXT NOT NULL,
            request_type TEXT NOT NULL,
            reason TEXT,
            status TEXT DEFAULT 'pending',
            admin_response TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (lecturer_id) REFERENCES users (id),
            FOREIGN KEY (course_id) REFERENCES courses (id)
        )
    ''')
    
    conn.execute('''
        CREATE TABLE IF NOT EXISTS user_courses (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            course_id TEXT NOT NULL,
            enrolled_at TEXT NOT NULL,
            last_sync TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id),
            FOREIGN KEY (course_id) REFERENCES courses (id),
            UNIQUE(user_id, course_id)
        )
    ''')
    
    # Insert default data if not exists
    now = datetime.now().isoformat()
    
    # Default roles with updated permissions based on requirements
    roles = [
        ('role_student', 'Student', 'Student role - view/download files from enrolled courses only',
         'view_enrolled_courses,download_files,view_targeted_announcements,edit_profile_basic'),
        ('role_lecturer', 'Lecturer', 'Lecturer role - manage assigned courses and communicate with admin',
         'manage_assigned_courses,upload_files,edit_uploaded_files,request_student_enrollment,create_course_announcements,view_general_announcements,chat_with_admin,share_files_with_admin'),
        ('role_admin', 'Admin', 'Administrator role - manage users/courses and communicate with lecturers',
         'manage_all_users,manage_all_courses,create_system_announcements,create_targeted_announcements,view_delete_lecturer_files,chat_with_lecturers,share_files_with_lecturers,enroll_remove_students'),
        ('role_super_admin', 'Super Admin', 'Super administrator with full system access and analytics',
         'full_access,manage_admins,view_system_logs,backup_restore,view_analytics,dual_password_auth'),
    ]

    print("🔧 Creating default roles...")
    for role_id, name, description, permissions in roles:
        conn.execute('''
            INSERT OR IGNORE INTO roles (id, name, description, permissions, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (role_id, name, description, permissions, now, now))
        print(f"   ✅ Role: {name}")

    # Verify roles were created
    role_count = conn.execute('SELECT COUNT(*) FROM roles').fetchone()[0]
    print(f"📊 Total roles in database: {role_count}")
    
    # Default users for testing
    default_users = [
        ('user_super_admin', 'superadmin', 'superadmin@velocityver.com', 'admin123', 'role_super_admin', 'Super', 'Admin'),
        ('user_admin', 'admin', 'admin@velocityver.com', 'admin123', 'role_admin', 'Test', 'Admin'),
        ('user_lecturer', 'lecturer', 'lecturer@velocityver.com', 'lecturer123', 'role_lecturer', 'Test', 'Lecturer'),
        ('user_student', 'student', 'student@velocityver.com', 'student123', 'role_student', 'Test', 'Student'),
    ]

    print("👥 Creating default users...")
    for user_id, username, email, password, role_id, first_name, last_name in default_users:
        password_hash = generate_password_hash(password)
        conn.execute('''
            INSERT OR IGNORE INTO users (id, username, email, password_hash, role_id, first_name, last_name, is_active, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (user_id, username, email, password_hash, role_id, first_name, last_name, 1, now, now))
        print(f"   ✅ User: {username}")

    # Verify users were created
    user_count = conn.execute('SELECT COUNT(*) FROM users').fetchone()[0]
    print(f"📊 Total users in database: {user_count}")
    
    # Nigerian University Academic Structure
    faculties = [
        ('fac_engineering', 'Faculty of Engineering'),
        ('fac_science', 'Faculty of Science'),
        ('fac_arts', 'Faculty of Arts'),
        ('fac_social_sciences', 'Faculty of Social Sciences'),
        ('fac_medicine', 'Faculty of Medicine'),
        ('fac_law', 'Faculty of Law'),
        ('fac_education', 'Faculty of Education'),
        ('fac_agriculture', 'Faculty of Agriculture'),
        ('fac_management', 'Faculty of Management Sciences'),
        ('fac_environmental', 'Faculty of Environmental Sciences'),
    ]

    print("🏛️ Creating Nigerian university faculties...")
    for fac_id, name in faculties:
        conn.execute('''
            INSERT OR IGNORE INTO faculties (id, name, created_at, updated_at)
            VALUES (?, ?, ?, ?)
        ''', (fac_id, name, now, now))
        print(f"   ✅ Faculty: {name}")

    departments = [
        # Engineering Departments
        ('dept_computer_science', 'Computer Science', 'fac_engineering'),
        ('dept_electrical_engineering', 'Electrical/Electronics Engineering', 'fac_engineering'),
        ('dept_mechanical_engineering', 'Mechanical Engineering', 'fac_engineering'),
        ('dept_civil_engineering', 'Civil Engineering', 'fac_engineering'),
        ('dept_chemical_engineering', 'Chemical Engineering', 'fac_engineering'),
        ('dept_petroleum_engineering', 'Petroleum Engineering', 'fac_engineering'),

        # Science Departments
        ('dept_mathematics', 'Mathematics', 'fac_science'),
        ('dept_physics', 'Physics', 'fac_science'),
        ('dept_chemistry', 'Chemistry', 'fac_science'),
        ('dept_biology', 'Biology', 'fac_science'),
        ('dept_biochemistry', 'Biochemistry', 'fac_science'),
        ('dept_microbiology', 'Microbiology', 'fac_science'),
        ('dept_geology', 'Geology', 'fac_science'),

        # Arts Departments
        ('dept_english', 'English Language', 'fac_arts'),
        ('dept_history', 'History', 'fac_arts'),
        ('dept_linguistics', 'Linguistics', 'fac_arts'),
        ('dept_philosophy', 'Philosophy', 'fac_arts'),
        ('dept_music', 'Music', 'fac_arts'),
        ('dept_theatre_arts', 'Theatre Arts', 'fac_arts'),

        # Social Sciences
        ('dept_economics', 'Economics', 'fac_social_sciences'),
        ('dept_political_science', 'Political Science', 'fac_social_sciences'),
        ('dept_sociology', 'Sociology', 'fac_social_sciences'),
        ('dept_psychology', 'Psychology', 'fac_social_sciences'),
        ('dept_geography', 'Geography', 'fac_social_sciences'),

        # Management Sciences
        ('dept_accounting', 'Accounting', 'fac_management'),
        ('dept_business_admin', 'Business Administration', 'fac_management'),
        ('dept_marketing', 'Marketing', 'fac_management'),
        ('dept_banking_finance', 'Banking and Finance', 'fac_management'),

        # Medicine
        ('dept_medicine_surgery', 'Medicine and Surgery', 'fac_medicine'),
        ('dept_nursing', 'Nursing Sciences', 'fac_medicine'),
        ('dept_pharmacy', 'Pharmacy', 'fac_medicine'),
        ('dept_dentistry', 'Dentistry', 'fac_medicine'),

        # Education
        ('dept_educational_admin', 'Educational Administration', 'fac_education'),
        ('dept_curriculum_instruction', 'Curriculum and Instruction', 'fac_education'),
        ('dept_guidance_counselling', 'Guidance and Counselling', 'fac_education'),

        # Agriculture
        ('dept_crop_production', 'Crop Production', 'fac_agriculture'),
        ('dept_animal_science', 'Animal Science', 'fac_agriculture'),
        ('dept_agricultural_economics', 'Agricultural Economics', 'fac_agriculture'),

        # Environmental Sciences
        ('dept_architecture', 'Architecture', 'fac_environmental'),
        ('dept_urban_planning', 'Urban and Regional Planning', 'fac_environmental'),
        ('dept_estate_management', 'Estate Management', 'fac_environmental'),

        # Law
        ('dept_private_law', 'Private Law', 'fac_law'),
        ('dept_public_law', 'Public Law', 'fac_law'),
    ]

    print("🏢 Creating Nigerian university departments...")
    for dept_id, name, faculty_id in departments:
        conn.execute('''
            INSERT OR IGNORE INTO departments (id, name, faculty_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
        ''', (dept_id, name, faculty_id, now, now))
        print(f"   ✅ Department: {name}")
    
    levels = [
        ('level_undergraduate', 'Undergraduate'),
        ('level_graduate', 'Graduate (Masters)'),
        ('level_postgraduate', 'Postgraduate (PhD)'),
    ]

    print("🎓 Creating academic levels...")
    for level_id, name in levels:
        conn.execute('''
            INSERT OR IGNORE INTO levels (id, name, created_at, updated_at)
            VALUES (?, ?, ?, ?)
        ''', (level_id, name, now, now))
        print(f"   ✅ Level: {name}")

    years = [
        ('year_1', 'Year 1 (100 Level)'),
        ('year_2', 'Year 2 (200 Level)'),
        ('year_3', 'Year 3 (300 Level)'),
        ('year_4', 'Year 4 (400 Level)'),
        ('year_5', 'Year 5 (500 Level)'),
        ('year_6', 'Year 6 (600 Level)'),
    ]

    print("📅 Creating academic years...")
    for year_id, name in years:
        conn.execute('''
            INSERT OR IGNORE INTO years (id, name, created_at, updated_at)
            VALUES (?, ?, ?, ?)
        ''', (year_id, name, now, now))
        print(f"   ✅ Year: {name}")

    # Create additional test users with proper academic assignments
    additional_users = [
        # More students
        ('user_student_cs_1', 'john_doe', 'john.doe@student.edu.ng', 'student123', 'role_student', 'John', 'Doe', 'level_undergraduate', 'year_2', 'dept_computer_science', 'fac_engineering'),
        ('user_student_cs_2', 'jane_smith', 'jane.smith@student.edu.ng', 'student123', 'role_student', 'Jane', 'Smith', 'level_undergraduate', 'year_3', 'dept_computer_science', 'fac_engineering'),
        ('user_student_ee_1', 'mike_johnson', 'mike.johnson@student.edu.ng', 'student123', 'role_student', 'Mike', 'Johnson', 'level_undergraduate', 'year_1', 'dept_electrical_engineering', 'fac_engineering'),
        ('user_student_math_1', 'sarah_wilson', 'sarah.wilson@student.edu.ng', 'student123', 'role_student', 'Sarah', 'Wilson', 'level_undergraduate', 'year_4', 'dept_mathematics', 'fac_science'),

        # More lecturers
        ('user_lecturer_cs_1', 'prof_adams', 'prof.adams@lecturer.edu.ng', 'lecturer123', 'role_lecturer', 'Prof. Robert', 'Adams', None, None, 'dept_computer_science', 'fac_engineering'),
        ('user_lecturer_cs_2', 'dr_brown', 'dr.brown@lecturer.edu.ng', 'lecturer123', 'role_lecturer', 'Dr. Emily', 'Brown', None, None, 'dept_computer_science', 'fac_engineering'),
        ('user_lecturer_ee_1', 'prof_davis', 'prof.davis@lecturer.edu.ng', 'lecturer123', 'role_lecturer', 'Prof. James', 'Davis', None, None, 'dept_electrical_engineering', 'fac_engineering'),
        ('user_lecturer_math_1', 'dr_taylor', 'dr.taylor@lecturer.edu.ng', 'lecturer123', 'role_lecturer', 'Dr. Lisa', 'Taylor', None, None, 'dept_mathematics', 'fac_science'),

        # More admins
        ('user_admin_2', 'admin_eng', 'admin.eng@admin.edu.ng', 'admin123', 'role_admin', 'Engineering', 'Admin', None, None, None, 'fac_engineering'),
        ('user_admin_3', 'admin_sci', 'admin.sci@admin.edu.ng', 'admin123', 'role_admin', 'Science', 'Admin', None, None, None, 'fac_science'),
    ]

    print("👥 Creating additional test users...")
    for user_data in additional_users:
        user_id, username, email, password, role_id, first_name, last_name, level_id, year_id, dept_id, fac_id = user_data
        password_hash = generate_password_hash(password)
        conn.execute('''
            INSERT OR IGNORE INTO users (id, username, email, password_hash, role_id, first_name, last_name,
                                       level_id, year_id, department_id, faculty_id, is_active, profile_picture, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (user_id, username, email, password_hash, role_id, first_name, last_name,
              level_id, year_id, dept_id, fac_id, 1, 'default_avatar.png', now, now))
        print(f"   ✅ User: {username} ({role_id.replace('role_', '').title()})")

    # Create comprehensive course catalog
    courses = [
        # Computer Science Courses
        ('course_cs_101', 'Introduction to Programming', 'CSC101', 'Basic programming concepts using Python', 'level_undergraduate', 'year_1', 'dept_computer_science', 'fac_engineering', 'user_lecturer_cs_1'),
        ('course_cs_201', 'Data Structures and Algorithms', 'CSC201', 'Fundamental data structures and algorithms', 'level_undergraduate', 'year_2', 'dept_computer_science', 'fac_engineering', 'user_lecturer_cs_1'),
        ('course_cs_301', 'Database Systems', 'CSC301', 'Database design and management systems', 'level_undergraduate', 'year_3', 'dept_computer_science', 'fac_engineering', 'user_lecturer_cs_2'),
        ('course_cs_401', 'Software Engineering', 'CSC401', 'Software development methodologies and practices', 'level_undergraduate', 'year_4', 'dept_computer_science', 'fac_engineering', 'user_lecturer_cs_2'),

        # Electrical Engineering Courses
        ('course_ee_101', 'Circuit Analysis I', 'EEE101', 'Basic electrical circuit analysis', 'level_undergraduate', 'year_1', 'dept_electrical_engineering', 'fac_engineering', 'user_lecturer_ee_1'),
        ('course_ee_201', 'Electronics I', 'EEE201', 'Introduction to electronic devices and circuits', 'level_undergraduate', 'year_2', 'dept_electrical_engineering', 'fac_engineering', 'user_lecturer_ee_1'),
        ('course_ee_301', 'Digital Signal Processing', 'EEE301', 'Digital signal processing techniques', 'level_undergraduate', 'year_3', 'dept_electrical_engineering', 'fac_engineering', 'user_lecturer_ee_1'),

        # Mathematics Courses
        ('course_math_101', 'Calculus I', 'MTH101', 'Differential and integral calculus', 'level_undergraduate', 'year_1', 'dept_mathematics', 'fac_science', 'user_lecturer_math_1'),
        ('course_math_201', 'Linear Algebra', 'MTH201', 'Vector spaces and linear transformations', 'level_undergraduate', 'year_2', 'dept_mathematics', 'fac_science', 'user_lecturer_math_1'),
        ('course_math_301', 'Real Analysis', 'MTH301', 'Advanced mathematical analysis', 'level_undergraduate', 'year_3', 'dept_mathematics', 'fac_science', 'user_lecturer_math_1'),

        # General Education Courses
        ('course_gen_101', 'Use of English', 'GST101', 'Communication skills in English', 'level_undergraduate', 'year_1', 'dept_english', 'fac_arts', 'user_lecturer'),
        ('course_gen_102', 'Nigerian Peoples and Culture', 'GST102', 'Introduction to Nigerian culture and history', 'level_undergraduate', 'year_1', 'dept_history', 'fac_arts', 'user_lecturer'),
    ]

    print("📚 Creating course catalog...")
    for course_data in courses:
        course_id, name, code, description, level_id, year_id, dept_id, fac_id, lecturer_id = course_data
        conn.execute('''
            INSERT OR IGNORE INTO courses (id, name, code, description, level_id, year_id, department_id, faculty_id, lecturer_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (course_id, name, code, description, level_id, year_id, dept_id, fac_id, lecturer_id, now, now))
        print(f"   ✅ Course: {code} - {name}")

    # Create student enrollments
    enrollments = [
        # John Doe (CS Year 2) enrollments
        ('enroll_1', 'user_student_cs_1', 'course_cs_101'),
        ('enroll_2', 'user_student_cs_1', 'course_cs_201'),
        ('enroll_3', 'user_student_cs_1', 'course_math_101'),
        ('enroll_4', 'user_student_cs_1', 'course_gen_101'),

        # Jane Smith (CS Year 3) enrollments
        ('enroll_5', 'user_student_cs_2', 'course_cs_201'),
        ('enroll_6', 'user_student_cs_2', 'course_cs_301'),
        ('enroll_7', 'user_student_cs_2', 'course_math_201'),

        # Mike Johnson (EE Year 1) enrollments
        ('enroll_8', 'user_student_ee_1', 'course_ee_101'),
        ('enroll_9', 'user_student_ee_1', 'course_math_101'),
        ('enroll_10', 'user_student_ee_1', 'course_gen_101'),
        ('enroll_11', 'user_student_ee_1', 'course_gen_102'),

        # Sarah Wilson (Math Year 4) enrollments
        ('enroll_12', 'user_student_math_1', 'course_math_301'),
        ('enroll_13', 'user_student_math_1', 'course_cs_301'),  # Cross-department enrollment
    ]

    print("📝 Creating student enrollments...")
    for enroll_id, user_id, course_id in enrollments:
        conn.execute('''
            INSERT OR IGNORE INTO user_courses (id, user_id, course_id, enrolled_at, last_sync)
            VALUES (?, ?, ?, ?, ?)
        ''', (enroll_id, user_id, course_id, now, now))
        print(f"   ✅ Enrolled: {user_id} in {course_id}")

    # Create sample announcements
    announcements = [
        ('ann_1', 'Welcome to New Academic Session', 'Welcome to the 2024/2025 academic session. All students are expected to register their courses online.', 'user_admin', 'Student,Lecturer', ''),
        ('ann_2', 'CS Department Meeting', 'All Computer Science students are invited to the departmental orientation on Friday.', 'user_lecturer_cs_1', 'Student', 'course_cs_101,course_cs_201,course_cs_301,course_cs_401'),
        ('ann_3', 'System Maintenance Notice', 'The learning management system will be under maintenance this weekend.', 'user_admin', 'Student,Lecturer,Admin', ''),
        ('ann_4', 'Mathematics Workshop', 'Special workshop on advanced calculus techniques for all mathematics students.', 'user_lecturer_math_1', 'Student', 'course_math_101,course_math_201,course_math_301'),
    ]

    print("📢 Creating sample announcements...")
    for ann_id, title, content, author_id, target_roles, target_courses in announcements:
        conn.execute('''
            INSERT OR IGNORE INTO announcements (id, title, content, author_id, target_roles, target_courses, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (ann_id, title, content, author_id, target_roles, target_courses, now, now))
        print(f"   ✅ Announcement: {title}")

    # Create sample chat messages
    messages = [
        ('msg_1', 'Hello Dr. Brown, I need to discuss the CS301 curriculum updates.', 'user_admin', 'user_lecturer_cs_2', None, 'text'),
        ('msg_2', 'Hi Admin, I have prepared the updated syllabus. When can we meet?', 'user_lecturer_cs_2', 'user_admin', None, 'text'),
        ('msg_3', 'Good morning Prof. Adams, please review the new student enrollment requests.', 'user_admin_2', 'user_lecturer_cs_1', None, 'text'),
    ]

    print("💬 Creating sample chat messages...")
    for msg_id, content, sender_id, receiver_id, chat_room_id, msg_type in messages:
        conn.execute('''
            INSERT OR IGNORE INTO messages (id, content, sender_id, receiver_id, chat_room_id, message_type, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (msg_id, content, sender_id, receiver_id, chat_room_id, msg_type, now, now))
        print(f"   ✅ Message: {sender_id} → {receiver_id}")

    # Add sync_metadata table
    conn.execute('''
        CREATE TABLE IF NOT EXISTS sync_metadata (
            id TEXT PRIMARY KEY,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT,
            table_name TEXT NOT NULL,
            record_id TEXT NOT NULL,
            action TEXT NOT NULL,
            data TEXT,
            synced_at TEXT,
            is_synced INTEGER DEFAULT 0
        )
    ''')

    print("✅ Database initialization completed with comprehensive seeded data!")
    print(f"📊 Summary:")
    faculty_count = conn.execute('SELECT COUNT(*) FROM faculties').fetchone()[0]
    dept_count = conn.execute('SELECT COUNT(*) FROM departments').fetchone()[0]
    course_count = conn.execute('SELECT COUNT(*) FROM courses').fetchone()[0]
    user_count = conn.execute('SELECT COUNT(*) FROM users').fetchone()[0]
    enrollment_count = conn.execute('SELECT COUNT(*) FROM user_courses').fetchone()[0]
    announcement_count = conn.execute('SELECT COUNT(*) FROM announcements').fetchone()[0]
    message_count = conn.execute('SELECT COUNT(*) FROM messages').fetchone()[0]

    print(f"   🏛️  Faculties: {faculty_count}")
    print(f"   🏢 Departments: {dept_count}")
    print(f"   📚 Courses: {course_count}")
    print(f"   👥 Users: {user_count}")
    print(f"   📝 Enrollments: {enrollment_count}")
    print(f"   📢 Announcements: {announcement_count}")
    print(f"   💬 Messages: {message_count}")

    conn.commit()
    conn.close()
def seed_chat_rooms():
    conn = get_db_connection()
    now = datetime.now().isoformat()

    # Get all admins & lecturers
    admins = conn.execute("SELECT id, first_name FROM users WHERE role = 'admin'").fetchall()
    lecturers = conn.execute("SELECT id, first_name FROM users WHERE role = 'lecturer'").fetchall()

    # Create one chat room per lecturer with admin included
    for lecturer in lecturers:
        room_id = str(uuid.uuid4())
        room_name = f"Chat with {lecturer['first_name']}"
        
        # Create the room
        conn.execute('''
            INSERT OR IGNORE INTO chat_rooms (id, name, created_by, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
        ''', (room_id, room_name, lecturer['id'], now, now))

        # Add lecturer as participant
        conn.execute('''
            INSERT OR IGNORE INTO chat_participants (id, room_id, user_id, joined_at)
            VALUES (?, ?, ?, ?)
        ''', (str(uuid.uuid4()), room_id, lecturer['id'], now))

        # Add all admins as participants
        for admin in admins:
            conn.execute('''
                INSERT OR IGNORE INTO chat_participants (id, room_id, user_id, joined_at)
                VALUES (?, ?, ?, ?)
            ''', (str(uuid.uuid4()), room_id, admin['id'], now))

    conn.commit()
    conn.close()
    print("✅ Chat rooms seeded successfully")
@app.route('/api/files/all', methods=['GET'])
def get_all_files():
    """
    Fetch all files from all subfolders in uploads/
    """
    uploads_dir = app.config['UPLOAD_FOLDER']
    files_list = []

    for root, _, files in os.walk(uploads_dir):
        for idx, filename in enumerate(files, start=1):
            file_path = os.path.join(root, filename)
            if os.path.isfile(file_path):
                # Get course_id from folder structure
                relative_path = os.path.relpath(file_path, uploads_dir)
                parts = relative_path.split(os.sep)
                course_id = parts[0] if parts else 'unknown'

                files_list.append({
                    "id": f"local_{len(files_list)+1}",
                    "name": filename,
                    "file_path": file_path,
                    "download_url": f"/uploads/{course_id}/{filename}",
                    "course_id": course_id,
                    "file_size": os.path.getsize(file_path),
                    "mime_type": 'application/octet-stream',
                    "uploaded_by": 'system'
                })

    return jsonify(files_list), 200

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# Health check endpoint
@app.route('/health', methods=['GET'])
def health_check():
    print(f"🏥 Health check from {request.remote_addr}")
    return jsonify({'status': 'healthy', 'timestamp': datetime.now().isoformat()})

@app.route('/api/test', methods=['GET'])
def test_endpoint():
    print(f"🧪 Test endpoint from {request.remote_addr}")
    return jsonify({'status': 'VelocityVer server running', 'version': '1.0'})

@app.route('/api/debug/users', methods=['GET'])
def debug_users():
    """Debug endpoint to check what users exist in database"""
    print(f"🔍 Debug users endpoint from {request.remote_addr}")
    try:
        conn = get_db_connection()
        users = conn.execute('''
            SELECT u.id, u.username, u.email, u.first_name, u.last_name, u.is_active, r.name as role_name
            FROM users u
            LEFT JOIN roles r ON u.role_id = r.id
            ORDER BY u.username
        ''').fetchall()
        conn.close()

        user_list = []
        for user in users:
            user_list.append({
                'id': user['id'],
                'username': user['username'],
                'email': user['email'],
                'first_name': user['first_name'],
                'last_name': user['last_name'],
                'is_active': user['is_active'],
                'role_name': user['role_name']
            })

        print(f"📊 Found {len(user_list)} users in database")
        for user in user_list:
            print(f"   👤 {user['username']} ({user['role_name']}) - Active: {user['is_active']}")

        return jsonify({'users': user_list, 'count': len(user_list)})
    except Exception as e:
        print(f"❌ Error in debug_users: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/debug/password/<username>/<password>', methods=['GET'])
def debug_password(username, password):
    """Debug endpoint to test password verification"""
    print(f"🔍 Debug password for {username} from {request.remote_addr}")
    try:
        conn = get_db_connection()
        user = conn.execute('SELECT username, password_hash FROM users WHERE username = ?', (username,)).fetchone()
        conn.close()

        if user:
            is_valid = check_password_hash(user['password_hash'], password)
            print(f"🔑 Password check for {username}: {is_valid}")
            return jsonify({
                'username': username,
                'password_provided': password,
                'hash_in_db': user['password_hash'][:50] + '...',
                'is_valid': is_valid
            })
        else:
            return jsonify({'error': f'User {username} not found'}), 404
    except Exception as e:
        print(f"❌ Error in debug_password: {e}")
        return jsonify({'error': str(e)}), 500
@app.route('/api/users/staff', methods=['GET'])
def get_staff():
    """
    Return all users who are either lecturers or admins.
    """
    conn = get_db_connection()
    staff = conn.execute('''
        SELECT id, first_name, last_name, email, role_id
        FROM users
        WHERE role_id IN ('role_lecturer', 'role_admin')
    ''').fetchall()
    conn.close()

    return jsonify({
        'items': [dict(user) for user in staff]
    }), 200

@app.route('/api/debug/login/<username>/<password>', methods=['GET'])
def debug_login_response(username, password):
    """Debug endpoint to see exact login response format"""
    print(f"🔍 Debug login response for {username} from {request.remote_addr}")
    try:
        conn = get_db_connection()
        user = conn.execute('''
            SELECT u.*, r.name as role_name, r.permissions
            FROM users u
            JOIN roles r ON u.role_id = r.id
            WHERE u.username = ? AND u.is_active = 1
        ''', (username,)).fetchone()

        if user and check_password_hash(user['password_hash'], password):
            user_data = {
                'id': user['id'],
                'username': user['username'],
                'email': user['email'],
                'role_id': user['role_id'],
                'role_name': user['role_name'],
                'first_name': user['first_name'],
                'last_name': user['last_name'],
                'permissions': user['permissions'].split(',') if user['permissions'] else []
            }
            conn.close()

            # This is exactly what the app should receive
            response_data = {'user': user_data, 'token': user['id']}
            print(f"📤 Login response data: {response_data}")
            return jsonify(response_data)
        else:
            conn.close()
            return jsonify({'error': 'Invalid credentials'}), 401
    except Exception as e:
        print(f"❌ Error in debug_login_response: {e}")
        return jsonify({'error': str(e)}), 500

# Authentication endpoints
@app.route('/api/auth/login', methods=['POST'])
def login():
    try:
        print(f"🔐 Login attempt from {request.remote_addr}")
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')

        print(f"👤 Login attempt - Username: '{username}', Password length: {len(password) if password else 0}")

        if not username or not password:
            print("❌ Missing username or password")
            return jsonify({'error': 'Username and password required'}), 400

        conn = get_db_connection()
        user = conn.execute('''
            SELECT u.*, r.name as role_name, r.permissions
            FROM users u
            JOIN roles r ON u.role_id = r.id
            WHERE u.username = ? AND u.is_active = 1
        ''', (username,)).fetchone()

        if user:
            print(f"✅ User found: {user['username']} (Role: {user['role_name']})")
            print(f"🔑 Checking password hash...")

            if check_password_hash(user['password_hash'], password):
                print(f"🎉 Login successful for user: {username}")
                user_data = {
                    'id': user['id'],
                    'username': user['username'],
                    'email': user['email'],
                    'role_id': user['role_id'],
                    'role_name': user['role_name'],
                    'first_name': user['first_name'],
                    'last_name': user['last_name'],
                    'permissions': user['permissions'].split(',') if user['permissions'] else []
                }
                conn.close()
                return jsonify({'user': user_data, 'token': user['id']})
            else:
                print(f"❌ Invalid password for user: {username}")
        else:
            print(f"❌ User not found: {username}")

        conn.close()
        return jsonify({'error': 'Invalid credentials'}), 401
    except Exception as e:
        print(f"❌ Login error: {e}")
        return jsonify({'error': 'Login failed'}), 500

# User management endpoints
@app.route('/api/users', methods=['GET'])
def get_users():
    since = request.args.get('since', '')
    conn = get_db_connection()

    query = 'SELECT * FROM users WHERE is_active = 1'
    params = []

    if since:
        query += ' AND updated_at > ?'
        params.append(since)

    users = conn.execute(query, params).fetchall()
    conn.close()

    return jsonify({
        'items': [dict(user) for user in users]
    })

@app.route('/api/users', methods=['POST'])
def create_user():
    data = request.get_json()

    # Validate required fields
    required_fields = ['username', 'email', 'password', 'role_id', 'first_name', 'last_name']
    for field in required_fields:
        if field not in data:
            return jsonify({'error': f'{field} is required'}), 400

    user_id = str(uuid.uuid4())
    password_hash = generate_password_hash(data['password'])
    now = datetime.now().isoformat()

    conn = get_db_connection()
    try:
        # Set default profile picture if none provided
        profile_picture = data.get('profile_picture', 'default_avatar.png')

        conn.execute('''
            INSERT INTO users (id, username, email, password_hash, role_id, first_name, last_name,
                             level_id, year_id, department_id, faculty_id, profile_picture, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (user_id, data['username'], data['email'], password_hash, data['role_id'],
              data['first_name'], data['last_name'], data.get('level_id'), data.get('year_id'),
              data.get('department_id'), data.get('faculty_id'), profile_picture, now, now))
        conn.commit()
        conn.close()
        return jsonify({'id': user_id, 'message': 'User created successfully'}), 201
    except sqlite3.IntegrityError as e:
        conn.close()
        return jsonify({'error': 'Username or email already exists'}), 409

@app.route('/api/users/<user_id>', methods=['PUT'])
def update_user(user_id):
    """Update user information with role-based restrictions"""
    data = request.get_json()
    conn = get_db_connection()

    # Get current user info to check role
    current_user = conn.execute('SELECT role_id FROM users WHERE id = ?', (user_id,)).fetchone()
    if not current_user:
        conn.close()
        return jsonify({'error': 'User not found'}), 404

    # Build dynamic update query with role-based field restrictions
    update_fields = []
    params = []

    # Students can only update basic profile info
    if current_user['role_id'] == 'role_student':
        allowed_fields = ['first_name', 'last_name', 'profile_picture']
    else:
        # Lecturers and admins can update more fields
        allowed_fields = ['username', 'email', 'first_name', 'last_name', 'level_id', 'year_id',
                         'department_id', 'faculty_id', 'profile_picture', 'is_active']

    for field in allowed_fields:
        if field in data:
            update_fields.append(f"{field} = ?")
            params.append(data[field])

    # Password update allowed for all users
    if 'password' in data:
        update_fields.append("password_hash = ?")
        params.append(generate_password_hash(data['password']))

    if not update_fields:
        conn.close()
        return jsonify({'error': 'No valid fields to update'}), 400

    update_fields.append("updated_at = ?")
    params.append(datetime.now().isoformat())
    params.append(user_id)

    query = f'UPDATE users SET {", ".join(update_fields)} WHERE id = ?'

    try:
        conn.execute(query, params)
        conn.commit()
        conn.close()
        print(f"✅ User {user_id} updated successfully")
        return jsonify({'message': 'User updated successfully'})
    except sqlite3.IntegrityError:
        conn.close()
        return jsonify({'error': 'Username or email already exists'}), 409

# Course management endpoints
@app.route('/api/courses', methods=['GET'])
def get_courses():
    since = request.args.get('since', '')
    conn = get_db_connection()

    query = 'SELECT * FROM courses WHERE is_active = 1'
    params = []

    if since:
        query += ' AND updated_at > ?'
        params.append(since)

    courses = conn.execute(query, params).fetchall()
    conn.close()

    # Return all fields, including lecturer_id
    return jsonify({
        'items': [dict(course) for course in courses]
    })
@app.route('/api/lecturers', methods=['GET'])
def get_lecturers():
    conn = get_db_connection()
    lecturers = conn.execute(
        'SELECT id, first_name, last_name, email FROM users WHERE role = ?',
        ('lecturer',)
    ).fetchall()
    conn.close()

    return jsonify({
        'items': [dict(lecturer) for lecturer in lecturers]
    })
@app.route('/api/courses', methods=['POST'])
def create_course():
    data = request.get_json()

    required_fields = ['name', 'code', 'level_id', 'year_id', 'department_id', 'faculty_id']
    for field in required_fields:
        if field not in data:
            return jsonify({'error': f'{field} is required'}), 400

    course_id = str(uuid.uuid4())
    now = datetime.now().isoformat()

    conn = get_db_connection()
    try:
        conn.execute('''
            INSERT INTO courses (id, name, code, description, level_id, year_id, department_id,
                               faculty_id, lecturer_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (course_id, data['name'], data['code'], data.get('description'),
              data['level_id'], data['year_id'], data['department_id'], data['faculty_id'],
              data.get('lecturer_id'), now, now))
        conn.commit()
        conn.close()
        return jsonify({'id': course_id, 'message': 'Course created successfully'}), 201
    except sqlite3.IntegrityError:
        conn.close()
        return jsonify({'error': 'Course code already exists'}), 409

# File management endpoints
@app.route('/api/files', methods=['GET'])
def get_files():
    since = request.args.get('since', '')
    conn = get_db_connection()

    query = 'SELECT * FROM files'
    params = []

    if since:
        query += ' WHERE updated_at > ?'
        params.append(since)

    files = conn.execute(query, params).fetchall()
    conn.close()

    return jsonify({
        'files': [dict(file) for file in files]
    })
@app.route('/api/lecturer/<user_id>/courses', methods=['GET'])
def get_lecturer_courses(user_id):
    """
    Get all active courses assigned to a specific lecturer.
    """
    conn = get_db_connection()
    courses = conn.execute(
        'SELECT * FROM courses WHERE lecturer_id = ? AND is_active = 1',
        (user_id,)
    ).fetchall()
    conn.close()

    return jsonify([dict(course) for course in courses]), 200
@app.route('/api/lecturer/<user_id>/files', methods=['GET'])
def get_lecturer_files(user_id):
    """
    Get all files uploaded by a specific lecturer.
    """
    conn = get_db_connection()
    files = conn.execute(
        'SELECT * FROM files WHERE uploaded_by = ?',
        (user_id,)
    ).fetchall()
    conn.close()

    return jsonify([dict(file) for file in files]), 200
@app.route('/api/lecturer/<user_id>/announcements', methods=['GET'])
def get_lecturer_announcements(user_id):
    """
    Get all announcements created by a specific lecturer.
    """
    conn = get_db_connection()
    announcements = conn.execute(
        'SELECT * FROM announcements WHERE created_by = ? AND is_active = 1 ORDER BY created_at DESC',
        (user_id,)
    ).fetchall()
    conn.close()

    return jsonify([dict(ann) for ann in announcements]), 200

# 2. Student courses
@app.route('/api/student/<user_id>/courses', methods=['GET'])
def get_student_courses(user_id):
    conn = get_db_connection()
    courses = conn.execute('''
        SELECT c.*
        FROM courses c
        JOIN enrollments e ON c.id = e.course_id
        WHERE e.student_id = ?
    ''', (user_id,)).fetchall()
    conn.close()
    return jsonify([dict(course) for course in courses]), 200


# 3. Student announcements
@app.route('/api/student/<user_id>/announcements', methods=['GET'])
def get_student_announcements(user_id):
    conn = get_db_connection()
    announcements = conn.execute('''
        SELECT a.*
        FROM announcements a
        JOIN courses c ON a.course_id = c.id
        JOIN enrollments e ON e.course_id = c.id
        WHERE e.student_id = ?
        ORDER BY a.created_at DESC
    ''', (user_id,)).fetchall()
    conn.close()
    return jsonify([dict(ann) for ann in announcements]), 200

@app.route('/api/enrollments', methods=['POST'])
def enroll_student():
    data = request.get_json()
    student_id = data.get('student_id')
    course_id = data.get('course_id')

    if not student_id or not course_id:
        return jsonify({'error': 'student_id and course_id required'}), 400

    conn = get_db_connection()
    try:
        conn.execute('''
            INSERT INTO enrollments (id, student_id, course_id, enrolled_at)
            VALUES (?, ?, ?, ?)
        ''', (str(uuid.uuid4()), student_id, course_id, datetime.now().isoformat()))
        conn.commit()
        conn.close()
        return jsonify({'message': 'Student enrolled successfully'}), 201
    except sqlite3.IntegrityError:
        conn.close()
        return jsonify({'error': 'Student already enrolled in this course'}), 409

# 4. Student downloads
@app.route('/api/files/downloaded', methods=['GET'])
def get_downloaded_files():
    user_id = request.args.get('user_id')
    conn = get_db_connection()
    downloads = conn.execute('''
        SELECT f.*
        FROM downloads d
        JOIN files f ON f.id = d.file_id
        WHERE d.user_id = ?
        ORDER BY d.downloaded_at DESC
    ''', (user_id,)).fetchall()
    conn.close()
    return jsonify([dict(file) for file in downloads]), 200


# 5. Chat rooms by user


# 6. Staff endpoint


@app.route('/api/files/uploads', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400

    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No file selected'}), 400

    # File type restrictions - only document types allowed
    allowed_extensions = {'.pdf', '.doc', '.docx', '.txt', '.rtf', '.odt', '.xls', '.xlsx', '.ppt', '.pptx', '.csv'}
    file_ext = os.path.splitext(file.filename)[1].lower()

    if file_ext not in allowed_extensions:
        return jsonify({'error': f'File type {file_ext} not allowed. Only document files are permitted.'}), 400

    # Check storage limit (10GB = 10,737,418,240 bytes)
    MAX_STORAGE_BYTES = 10 * 1024 * 1024 * 1024  # 10GB

    # Get current total file size for the user
    conn = get_db_connection()
    current_usage = conn.execute('''
        SELECT COALESCE(SUM(file_size), 0) as total_size
        FROM files
        WHERE uploaded_by = ?
    ''', (request.form.get('uploaded_by'),)).fetchone()

    current_size = current_usage['total_size'] if current_usage else 0
    file_size = len(file.read())
    file.seek(0)  # Reset file pointer

    if current_size + file_size > MAX_STORAGE_BYTES:
        conn.close()
        remaining_mb = (MAX_STORAGE_BYTES - current_size) / (1024 * 1024)
        return jsonify({'error': f'Storage limit exceeded. You have {remaining_mb:.1f}MB remaining of your 10GB quota.'}), 400

    conn.close()

    if not allowed_file(file.filename):
        return jsonify({'error': 'File type not allowed'}), 400

    # Get form data
    file_id = request.form.get('file_id', str(uuid.uuid4()))
    course_id = request.form.get('course_id')
    uploaded_by = request.form.get('uploaded_by')
    description = request.form.get('description', '')

    if not course_id or not uploaded_by:
        return jsonify({'error': 'course_id and uploaded_by are required'}), 400

    # Create course-specific directory
    course_dir = os.path.join(app.config['UPLOAD_FOLDER'], course_id)
    os.makedirs(course_dir, exist_ok=True)

    # Save file
    filename = secure_filename(file.filename)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    unique_filename = f"{timestamp}_{filename}"
    file_path = os.path.join(course_dir, unique_filename)

    file.save(file_path)
    file_size = os.path.getsize(file_path)

    # Save to database
    now = datetime.now().isoformat()
    conn = get_db_connection()

    conn.execute('''
        INSERT OR REPLACE INTO files (id, name, original_name, file_path, file_size, mime_type,
                                    course_id, uploaded_by, description, server_path, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', (file_id, unique_filename, filename, file_path, file_size, file.content_type or 'application/octet-stream',
          course_id, uploaded_by, description, file_path, now, now))

    conn.commit()
    conn.close()

    return jsonify({
        'id': file_id,
        'message': 'File uploaded successfully',
        'filename': unique_filename
    }), 201
@app.route('/api/courses/<course_id>/files', methods=['GET'])
def get_course_files(course_id):
    course_dir = os.path.join(app.config['UPLOAD_FOLDER'], course_id)

    if not os.path.exists(course_dir):
        return jsonify([]), 200

    conn = get_db_connection()
    files_in_db = conn.execute(
        'SELECT * FROM files WHERE course_id = ?', (course_id,)
    ).fetchall()
    conn.close()

    files_list = []

    if files_in_db:
        for file_row in files_in_db:
            file_path = file_row['file_path']
            if os.path.exists(file_path):
                files_list.append({
                    'id': file_row['id'],
                    'name': file_row['name'],
                    'original_name': file_row['original_name'],
                    'file_path': file_row['file_path'],   # ✅ Added
                    'file_size': file_row['file_size'],
                    'mime_type': file_row['mime_type'] or 'application/octet-stream',
                    'course_id': file_row['course_id'],
                    'uploaded_by': file_row['uploaded_by'] or 'system',
                    'description': file_row['description'],
                    'created_at': file_row['created_at'],
                    'updated_at': file_row['updated_at'],
                })
    else:
        for idx, filename in enumerate(os.listdir(course_dir), start=1):
            file_path = os.path.join(course_dir, filename)
            if os.path.isfile(file_path):
                files_list.append({
                    'id': f"local_{idx}",
                    'name': filename,
                    'original_name': filename,
                    'file_path': file_path,   # ✅ Added for Flutter mapping
                    'file_size': os.path.getsize(file_path),
                    'mime_type': 'application/octet-stream',
                    'course_id': course_id,
                    'uploaded_by': 'system',
                    'description': None,
                    'created_at': None,
                    'updated_at': None,
                })

    return jsonify(files_list), 200
@app.route('/api/courses/<course_id>/folder-files', methods=['GET'])
def get_course_folder_files(course_id):
    """
    Return all files directly from uploads/<course_id> folder.
    """
    course_dir = os.path.join(app.config['UPLOAD_FOLDER'], course_id)

    if not os.path.exists(course_dir):
        return jsonify([]), 200

    files_list = []
    for idx, filename in enumerate(os.listdir(course_dir), start=1):
        file_path = os.path.join(course_dir, filename)
        if os.path.isfile(file_path):
            files_list.append({
                "id": f"local_{idx}",
                "name": filename,
                "file_size": os.path.getsize(file_path),
                "download_url": f"/uploads/{course_id}/{filename}"  # <-- direct URL
            })

    return jsonify(files_list), 200
@app.route('/uploads/<course_id>/<filename>')
def serve_uploaded_file(course_id, filename):
    return send_from_directory(
        os.path.join(app.config['UPLOAD_FOLDER'], course_id),
        filename,
        as_attachment=True
    )

@app.route('/api/files/<file_id>/download', methods=['GET'])
def download_file(file_id):
    """
    Download a file by its ID.
    Works for DB entries and fallback local files (local_X ids).
    """
    conn = get_db_connection()
    file_record = conn.execute(
        'SELECT * FROM files WHERE id = ?', (file_id,)
    ).fetchone()
    conn.close()

    if file_record:  # ✅ DB record exists
        file_path = file_record['server_path'] or file_record['file_path']
        if not os.path.exists(file_path):
            return jsonify({'error': 'File not found on disk'}), 404

        directory, filename = os.path.split(file_path)
        return send_from_directory(
            directory,
            filename,
            as_attachment=True,
            download_name=file_record['original_name'],
            mimetype=file_record['mime_type'] or 'application/octet-stream'
        )

    # ✅ Handle fallback local files
    if file_id.startswith("local_"):
        try:
            idx = int(file_id.replace("local_", ""))
        except ValueError:
            return jsonify({'error': 'Invalid file ID'}), 400

        # Look for the file in uploads
        uploads_dir = app.config['UPLOAD_FOLDER']
        all_files = []
        for root, _, files in os.walk(uploads_dir):
            for f in files:
                all_files.append(os.path.join(root, f))

        if idx <= len(all_files):
            file_path = all_files[idx - 1]
            directory, filename = os.path.split(file_path)
            return send_from_directory(
                directory,
                filename,
                as_attachment=True,
                download_name=filename
            )

    return jsonify({'error': 'File not found'}), 404
# Announcement endpoints
@app.route('/api/announcements', methods=['GET'])
def get_announcements():
    since = request.args.get('since', '')
    conn = get_db_connection()

    query = 'SELECT * FROM announcements WHERE is_active = 1'
    params = []

    if since:
        query += ' AND updated_at > ?'
        params.append(since)

    query += ' ORDER BY created_at DESC'

    announcements = conn.execute(query, params).fetchall()
    conn.close()

    return jsonify({
        'items': [dict(announcement) for announcement in announcements]
    })

@app.route('/api/announcements', methods=['POST'])
def create_announcement():
    data = request.get_json()

    required_fields = ['title', 'content', 'author_id']
    for field in required_fields:
        if field not in data:
            return jsonify({'error': f'{field} is required'}), 400

    announcement_id = str(uuid.uuid4())
    now = datetime.now().isoformat()

    target_roles = ','.join(data.get('target_roles', []))
    target_courses = ','.join(data.get('target_courses', []))

    conn = get_db_connection()
    conn.execute('''
        INSERT INTO announcements (id, title, content, author_id, target_roles, target_courses, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', (announcement_id, data['title'], data['content'], data['author_id'],
          target_roles, target_courses, now, now))

    conn.commit()
    conn.close()

    return jsonify({'id': announcement_id, 'message': 'Announcement created successfully'}), 201

# Roles endpoints
@app.route('/api/roles', methods=['GET'])
def get_roles():
    try:
        print(f"📡 GET /api/roles - Request from {request.remote_addr}")
        since = request.args.get('since', '')
        conn = get_db_connection()

        query = 'SELECT * FROM roles'
        params = []

        if since:
            query += ' WHERE updated_at > ?'
            params.append(since)

        roles = conn.execute(query, params).fetchall()
        conn.close()

        result = {'items': [dict(role) for role in roles]}
        print(f"✅ Returning {len(result['items'])} roles")
        return jsonify(result)
    except Exception as e:
        print(f"❌ Error in get_roles: {e}")
        return jsonify({'error': str(e)}), 500

# Faculties endpoints
@app.route('/api/faculties', methods=['GET'])
def get_faculties():
    since = request.args.get('since', '')
    conn = get_db_connection()

    query = 'SELECT * FROM faculties'
    params = []

    if since:
        query += ' WHERE updated_at > ?'
        params.append(since)

    faculties = conn.execute(query, params).fetchall()
    conn.close()

    return jsonify({
        'items': [dict(faculty) for faculty in faculties]
    })

# Departments endpoints
@app.route('/api/departments', methods=['GET'])
def get_departments():
    since = request.args.get('since', '')
    conn = get_db_connection()

    query = 'SELECT * FROM departments'
    params = []

    if since:
        query += ' WHERE updated_at > ?'
        params.append(since)

    departments = conn.execute(query, params).fetchall()
    conn.close()

    return jsonify({
        'items': [dict(department) for department in departments]
    })

# Levels endpoints
@app.route('/api/levels', methods=['GET'])
def get_levels():
    since = request.args.get('since', '')
    conn = get_db_connection()

    query = 'SELECT * FROM levels'
    params = []

    if since:
        query += ' WHERE updated_at > ?'
        params.append(since)

    levels = conn.execute(query, params).fetchall()
    conn.close()

    return jsonify({
        'items': [dict(level) for level in levels]
    })

# Years endpoints
@app.route('/api/years', methods=['GET'])
def get_years():
    since = request.args.get('since', '')
    conn = get_db_connection()

    query = 'SELECT * FROM years'
    params = []

    if since:
        query += ' WHERE updated_at > ?'
        params.append(since)

    years = conn.execute(query, params).fetchall()
    conn.close()

    return jsonify({
        'items': [dict(year) for year in years]
    })

# User courses endpoints
@app.route('/api/user-courses', methods=['GET'])
def get_user_courses():
    since = request.args.get('since', '')
    conn = get_db_connection()

    query = 'SELECT * FROM user_courses'
    params = []

    if since:
        query += ' WHERE last_sync > ?'
        params.append(since)

    user_courses = conn.execute(query, params).fetchall()
    conn.close()

    return jsonify({
        'items': [dict(uc) for uc in user_courses]
    })

# Chat system endpoints
@app.route('/api/chat/rooms', methods=['GET'])
def get_chat_rooms():
    """Get chat rooms for current user"""
    try:
        user_id = request.args.get('user_id')
        if not user_id:
            return jsonify({'error': 'User ID required'}), 400

        conn = get_db_connection()
        rooms = conn.execute('''
            SELECT * FROM chat_rooms
            WHERE participant_ids LIKE ? AND is_active = 1
            ORDER BY last_activity DESC
        ''', (f'%{user_id}%',)).fetchall()
        conn.close()

        return jsonify({'items': [dict(room) for room in rooms]})
    except Exception as e:
        print(f"❌ Error getting chat rooms: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/chat/messages', methods=['GET'])
def get_chat_messages():
    """Get messages for a chat room or between two users"""
    try:
        chat_room_id = request.args.get('chat_room_id')
        sender_id = request.args.get('sender_id')
        receiver_id = request.args.get('receiver_id')

        conn = get_db_connection()

        if chat_room_id:
            messages = conn.execute('''
                SELECT * FROM messages
                WHERE chat_room_id = ?
                ORDER BY created_at ASC
            ''', (chat_room_id,)).fetchall()
        elif sender_id and receiver_id:
            messages = conn.execute('''
                SELECT * FROM messages
                WHERE (sender_id = ? AND receiver_id = ?)
                   OR (sender_id = ? AND receiver_id = ?)
                ORDER BY created_at ASC
            ''', (sender_id, receiver_id, receiver_id, sender_id)).fetchall()
        else:
            conn.close()
            return jsonify({'error': 'chat_room_id or sender_id+receiver_id required'}), 400

        conn.close()
        return jsonify({'items': [dict(message) for message in messages]})
    except Exception as e:
        print(f"❌ Error getting messages: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/chat/messages', methods=['POST'])
def send_message():
    """Send a new message"""
    try:
        data = request.get_json()
        message_id = f"msg_{int(time.time() * 1000)}"
        now = datetime.now().isoformat()

        conn = get_db_connection()
        conn.execute('''
            INSERT INTO messages (id, content, sender_id, receiver_id, chat_room_id,
                                message_type, file_id, file_name, file_url, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (message_id, data.get('content', ''), data['sender_id'],
              data.get('receiver_id'), data.get('chat_room_id'),
              data.get('message_type', 'text'), data.get('file_id'),
              data.get('file_name'), data.get('file_url'), now, now))

        # Update chat room last activity if applicable
        if data.get('chat_room_id'):
            conn.execute('''
                UPDATE chat_rooms
                SET last_message_id = ?, last_activity = ?, updated_at = ?
                WHERE id = ?
            ''', (message_id, now, now, data['chat_room_id']))

        conn.commit()
        conn.close()

        print(f"💬 Message sent from {data['sender_id']} to {data.get('receiver_id', 'group')}")
        return jsonify({'id': message_id, 'message': 'Message sent successfully'}), 201
    except Exception as e:
        print(f"❌ Error sending message: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/courses/<course_id>/enroll', methods=['POST'])
def enroll_student_in_course(course_id):
    """Enroll a student in a course (Admin only)"""
    try:
        data = request.get_json()
        student_id = data.get('student_id')

        if not student_id:
            return jsonify({'error': 'Student ID required'}), 400

        conn = get_db_connection()

        # Check if student exists and is actually a student
        student = conn.execute('''
            SELECT id, role_id FROM users WHERE id = ? AND role_id = 'role_student'
        ''', (student_id,)).fetchone()

        if not student:
            conn.close()
            return jsonify({'error': 'Student not found'}), 404

        # Check if course exists
        course = conn.execute('SELECT id FROM courses WHERE id = ?', (course_id,)).fetchone()
        if not course:
            conn.close()
            return jsonify({'error': 'Course not found'}), 404

        # Check if already enrolled
        existing = conn.execute('''
            SELECT id FROM user_courses WHERE user_id = ? AND course_id = ?
        ''', (student_id, course_id)).fetchone()

        if existing:
            conn.close()
            return jsonify({'error': 'Student already enrolled in this course'}), 409

        # Create enrollment
        enrollment_id = f"enroll_{int(time.time() * 1000)}"
        now = datetime.now().isoformat()

        conn.execute('''
            INSERT INTO user_courses (id, user_id, course_id, enrolled_at, last_sync)
            VALUES (?, ?, ?, ?, ?)
        ''', (enrollment_id, student_id, course_id, now, now))

        conn.commit()
        conn.close()

        print(f"✅ Student {student_id} enrolled in course {course_id}")
        return jsonify({'id': enrollment_id, 'message': 'Student enrolled successfully'}), 201

    except Exception as e:
        print(f"❌ Error enrolling student: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/courses/<course_id>/unenroll', methods=['DELETE'])
def unenroll_student_from_course(course_id):
    """Remove a student from a course (Admin only)"""
    try:
        data = request.get_json()
        student_id = data.get('student_id')

        if not student_id:
            return jsonify({'error': 'Student ID required'}), 400

        conn = get_db_connection()

        # Remove enrollment
        result = conn.execute('''
            DELETE FROM user_courses WHERE user_id = ? AND course_id = ?
        ''', (student_id, course_id))

        if result.rowcount == 0:
            conn.close()
            return jsonify({'error': 'Enrollment not found'}), 404

        conn.commit()
        conn.close()

        print(f"✅ Student {student_id} unenrolled from course {course_id}")
        return jsonify({'message': 'Student unenrolled successfully'})

    except Exception as e:
        print(f"❌ Error unenrolling student: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/admin/stats', methods=['GET'])
def get_admin_stats():
    conn = get_db_connection()
    stats = {
        "total_users": conn.execute("SELECT COUNT(*) FROM users").fetchone()[0],
        "total_faculties": conn.execute("SELECT COUNT(*) FROM faculties").fetchone()[0],
        "total_departments": conn.execute("SELECT COUNT(*) FROM departments").fetchone()[0],
        "total_courses": conn.execute("SELECT COUNT(*) FROM courses").fetchone()[0],
        "total_announcements": conn.execute("SELECT COUNT(*) FROM announcements").fetchone()[0],
        "total_files": conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
    }
    conn.close()
    return jsonify(stats)

if __name__ == '__main__':
    try:
        print("🔄 Checking database...")
        init_database()
        print("✅ Database ready!")

        print("=" * 60)
        print("🚀 VelocityVer Server Starting...")
        print("=" * 60)

        # Get local IP address safely
        try:
            import socket
            hostname = socket.gethostname()
            local_ip = socket.gethostbyname(hostname)
        except Exception as e:
            print(f"⚠️  Could not get local IP: {e}")
            local_ip = "localhost"

        print(f"📱 Server accessible at:")
        print(f"   Local:    http://localhost:5000")
        print(f"   Network:  http://{local_ip}:5000")
        print(f"   Health:   http://{local_ip}:5000/health")
        print("=" * 60)
        print("📁 Upload folder:", os.path.abspath(UPLOAD_FOLDER))
        print("🗄️  Database:", os.path.abspath(DATABASE_PATH))
        print("=" * 60)
        print("🔑 Default logins:")
        print("   Student:  student / student123")
        print("   Lecturer: lecturer / lecturer123")
        print("   Admin:    admin / admin123")
        print("   Super Admin: superadmin / admin123")
        print("=" * 60)
        print("⚠️  If connection fails:")
        print("   1. Check Windows Firewall settings")
        print("   2. Make sure devices are on same Wi-Fi")
        print("   3. Try http://localhost:5000/health in browser")
        print("=" * 60)
        print("🚀 Starting Flask server...")

        app.run(host='0.0.0.0', port=5000, debug=False)
    except Exception as e:
        print(f"❌ Server startup error: {e}")
        import traceback
        traceback.print_exc()
