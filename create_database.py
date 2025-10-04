#!/usr/bin/env python3
"""
Create a pre-built SQLite database for VelocityVer app
This creates the database with all tables and default data
"""

import sqlite3
import hashlib
import uuid
from datetime import datetime
import os

def hash_password(password):
    """Hash password using SHA-256 (same as Flutter app)"""
    return hashlib.sha256(password.encode()).hexdigest()

def create_database():
    # Remove existing database if it exists
    db_path = 'assets/velocityver.db'
    if os.path.exists(db_path):
        os.remove(db_path)
    
    # Create assets directory if it doesn't exist
    os.makedirs('assets', exist_ok=True)
    
    # Create database connection
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print("🗄️ Creating database tables...")
    
    # Create tables
    tables = [
        '''CREATE TABLE roles (
            id TEXT PRIMARY KEY,
            name TEXT UNIQUE NOT NULL,
            description TEXT,
            permissions TEXT NOT NULL,
            is_active INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT
        )''',
        
        '''CREATE TABLE faculties (
            id TEXT PRIMARY KEY,
            name TEXT UNIQUE NOT NULL,
            code TEXT UNIQUE NOT NULL,
            description TEXT,
            dean_id TEXT,
            is_active INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT
        )''',
        
        '''CREATE TABLE departments (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            code TEXT UNIQUE NOT NULL,
            faculty_id TEXT NOT NULL,
            description TEXT,
            hod_id TEXT,
            is_active INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT,
            FOREIGN KEY (faculty_id) REFERENCES faculties (id)
        )''',
        
        '''CREATE TABLE levels (
            id TEXT PRIMARY KEY,
            name TEXT UNIQUE NOT NULL,
            code TEXT UNIQUE NOT NULL,
            description TEXT,
            order_index INTEGER NOT NULL,
            is_active INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT
        )''',
        
        '''CREATE TABLE years (
            id TEXT PRIMARY KEY,
            name TEXT UNIQUE NOT NULL,
            code TEXT UNIQUE NOT NULL,
            description TEXT,
            order_index INTEGER NOT NULL,
            is_active INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT
        )''',
        
        '''CREATE TABLE users (
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
            is_active INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT,
            FOREIGN KEY (role_id) REFERENCES roles (id)
        )''',
        
        '''CREATE TABLE courses (
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
        )''',
        
        '''CREATE TABLE files (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            path TEXT NOT NULL,
            description TEXT,
            size INTEGER NOT NULL,
            mime_type TEXT NOT NULL,
            uploaded_by TEXT NOT NULL,
            course_id TEXT,
            target_roles TEXT,
            is_public INTEGER DEFAULT 0,
            download_count INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            last_sync TEXT,
            FOREIGN KEY (uploaded_by) REFERENCES users (id),
            FOREIGN KEY (course_id) REFERENCES courses (id)
        )''',
        
        '''CREATE TABLE announcements (
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
        )''',
        
        '''CREATE TABLE user_courses (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            course_id TEXT NOT NULL,
            enrolled_at TEXT NOT NULL,
            last_sync TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id),
            FOREIGN KEY (course_id) REFERENCES courses (id),
            UNIQUE(user_id, course_id)
        )'''
    ]
    
    for table in tables:
        cursor.execute(table)
    
    print("✅ Tables created successfully")
    
    # Insert default data
    now = datetime.now().isoformat()
    
    print("📝 Inserting default data...")
    
    # Default roles
    roles = [
        ('role_student', 'Student', 'Student role with access to course materials', 'view_courses,download_files,view_announcements'),
        ('role_lecturer', 'Lecturer', 'Lecturer role with course management capabilities', 'view_courses,manage_course_files,view_announcements,upload_files'),
        ('role_admin', 'Admin', 'Administrator role with user and system management', 'manage_users,manage_courses,manage_announcements,view_all_files,manage_system'),
        ('role_super_admin', 'Super Admin', 'Super administrator with full system access', 'full_access'),
    ]
    
    for role_id, name, description, permissions in roles:
        cursor.execute('''
            INSERT INTO roles (id, name, description, permissions, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (role_id, name, description, permissions, now, now))
    
    # Realistic faculties based on Nigerian universities
    faculties = [
        ('fac_engineering', 'Faculty of Engineering', 'ENG', 'Faculty of Engineering offering various engineering disciplines'),
        ('fac_science', 'Faculty of Physical Sciences', 'SCI', 'Faculty of Physical Sciences covering natural sciences'),
        ('fac_social_sciences', 'Faculty of Social Sciences', 'SOC', 'Faculty of Social Sciences and humanities'),
        ('fac_management', 'Faculty of Management Sciences', 'MGT', 'Faculty of Management and Business Sciences'),
        ('fac_education', 'Faculty of Education', 'EDU', 'Faculty of Education and teacher training'),
        ('fac_law', 'Faculty of Law', 'LAW', 'Faculty of Law and legal studies'),
        ('fac_medicine', 'Faculty of Medicine', 'MED', 'Faculty of Medicine and health sciences'),
    ]

    for fac_id, name, code, description in faculties:
        cursor.execute('''
            INSERT INTO faculties (id, name, code, description, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (fac_id, name, code, description, now, now))

    # Realistic departments
    departments = [
        # Engineering Faculty
        ('dept_computer_science', 'Computer Science', 'CSC', 'fac_engineering', 'Department of Computer Science and Information Technology'),
        ('dept_electrical_engineering', 'Electrical Engineering', 'EEE', 'fac_engineering', 'Department of Electrical and Electronics Engineering'),
        ('dept_mechanical_engineering', 'Mechanical Engineering', 'MEE', 'fac_engineering', 'Department of Mechanical Engineering'),
        ('dept_civil_engineering', 'Civil Engineering', 'CVE', 'fac_engineering', 'Department of Civil Engineering'),
        ('dept_chemical_engineering', 'Chemical Engineering', 'CHE', 'fac_engineering', 'Department of Chemical Engineering'),

        # Physical Sciences Faculty
        ('dept_mathematics', 'Mathematics', 'MTH', 'fac_science', 'Department of Mathematics'),
        ('dept_physics', 'Physics', 'PHY', 'fac_science', 'Department of Physics'),
        ('dept_chemistry', 'Chemistry', 'CHM', 'fac_science', 'Department of Chemistry'),
        ('dept_statistics', 'Statistics', 'STA', 'fac_science', 'Department of Statistics'),
        ('dept_geology', 'Geology', 'GEO', 'fac_science', 'Department of Geology'),

        # Social Sciences Faculty
        ('dept_economics', 'Economics', 'ECO', 'fac_social_sciences', 'Department of Economics'),
        ('dept_political_science', 'Political Science', 'POL', 'fac_social_sciences', 'Department of Political Science'),
        ('dept_sociology', 'Sociology', 'SOC', 'fac_social_sciences', 'Department of Sociology'),
        ('dept_psychology', 'Psychology', 'PSY', 'fac_social_sciences', 'Department of Psychology'),

        # Management Sciences Faculty
        ('dept_accounting', 'Accounting', 'ACC', 'fac_management', 'Department of Accounting'),
        ('dept_business_admin', 'Business Administration', 'BUS', 'fac_management', 'Department of Business Administration'),
        ('dept_marketing', 'Marketing', 'MKT', 'fac_management', 'Department of Marketing'),
        ('dept_banking_finance', 'Banking and Finance', 'BNF', 'fac_management', 'Department of Banking and Finance'),

        # Education Faculty
        ('dept_educational_foundations', 'Educational Foundations', 'EDF', 'fac_education', 'Department of Educational Foundations'),
        ('dept_curriculum_instruction', 'Curriculum and Instruction', 'CUR', 'fac_education', 'Department of Curriculum and Instruction'),

        # Law Faculty
        ('dept_private_law', 'Private Law', 'PRL', 'fac_law', 'Department of Private and Commercial Law'),
        ('dept_public_law', 'Public Law', 'PUL', 'fac_law', 'Department of Public and International Law'),

        # Medicine Faculty
        ('dept_medicine_surgery', 'Medicine and Surgery', 'MED', 'fac_medicine', 'Department of Medicine and Surgery'),
        ('dept_nursing', 'Nursing Sciences', 'NUR', 'fac_medicine', 'Department of Nursing Sciences'),
    ]

    for dept_id, name, code, faculty_id, description in departments:
        cursor.execute('''
            INSERT INTO departments (id, name, code, faculty_id, description, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (dept_id, name, code, faculty_id, description, now, now))
    
    # Academic levels (Nigerian university system)
    levels = [
        ('level_undergraduate', 'Undergraduate', 'UG', 1, 'Bachelor\'s degree programs (100L-400L/500L)'),
        ('level_postgraduate_diploma', 'Postgraduate Diploma', 'PGD', 2, 'Postgraduate Diploma programs'),
        ('level_masters', 'Masters Degree', 'MSC', 3, 'Master\'s degree programs'),
        ('level_doctorate', 'Doctorate Degree', 'PHD', 4, 'Doctoral degree programs'),
    ]

    for level_id, name, code, order, description in levels:
        cursor.execute('''
            INSERT INTO levels (id, name, code, order_index, description, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (level_id, name, code, order, description, now, now))

    # Academic years (Nigerian system uses levels like 100L, 200L, etc.)
    years = [
        ('year_100l', '100 Level', '100L', 1, 'First year undergraduate students'),
        ('year_200l', '200 Level', '200L', 2, 'Second year undergraduate students'),
        ('year_300l', '300 Level', '300L', 3, 'Third year undergraduate students'),
        ('year_400l', '400 Level', '400L', 4, 'Fourth year undergraduate students'),
        ('year_500l', '500 Level', '500L', 5, 'Fifth year undergraduate students (for 5-year programs)'),
        ('year_600l', '600 Level', '600L', 6, 'Sixth year undergraduate students (for 6-year programs like Medicine)'),
        ('year_pgd', 'PGD Year', 'PGD', 7, 'Postgraduate Diploma students'),
        ('year_msc1', 'MSc Year 1', 'MSC1', 8, 'First year Master\'s students'),
        ('year_msc2', 'MSc Year 2', 'MSC2', 9, 'Second year Master\'s students'),
        ('year_phd1', 'PhD Year 1', 'PHD1', 10, 'First year PhD students'),
        ('year_phd2', 'PhD Year 2', 'PHD2', 11, 'Second year PhD students'),
        ('year_phd3', 'PhD Year 3', 'PHD3', 12, 'Third year PhD students'),
    ]

    for year_id, name, code, order, description in years:
        cursor.execute('''
            INSERT INTO years (id, name, code, order_index, description, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (year_id, name, code, order, description, now, now))
    
    # Realistic users with Nigerian names and proper academic structure
    users = [
        # Super Admin
        ('user_super_admin', 'superadmin', 'superadmin@newgateuniversity.edu.ng', 'admin123', 'role_super_admin', 'System', 'Administrator', None, None, None, None),

        # Administrators
        ('user_admin_1', 'admin', 'admin@newgateuniversity.edu.ng', 'admin123', 'role_admin', 'Dr. Amina', 'Abdullahi', None, None, None, None),
        ('user_admin_2', 'registrar', 'registrar@newgateuniversity.edu.ng', 'admin123', 'role_admin', 'Prof. Ibrahim', 'Musa', None, None, None, None),

        # Lecturers from different departments
        ('user_lecturer_1', 'dr.adebayo', 'adebayo@newgateuniversity.edu.ng', 'lecturer123', 'role_lecturer', 'Dr. Adebayo', 'Ogundimu', None, None, 'dept_computer_science', 'fac_engineering'),
        ('user_lecturer_2', 'prof.hassan', 'hassan@newgateuniversity.edu.ng', 'lecturer123', 'role_lecturer', 'Prof. Hassan', 'Umar', None, None, 'dept_computer_science', 'fac_engineering'),
        ('user_lecturer_3', 'dr.fatima', 'fatima@newgateuniversity.edu.ng', 'lecturer123', 'role_lecturer', 'Dr. Fatima', 'Aliyu', None, None, 'dept_mathematics', 'fac_science'),
        ('user_lecturer_4', 'dr.ibrahim', 'ibrahim@newgateuniversity.edu.ng', 'lecturer123', 'role_lecturer', 'Dr. Ibrahim', 'Mohammed', None, None, 'dept_electrical_engineering', 'fac_engineering'),
        ('user_lecturer_5', 'prof.aisha', 'aisha@newgateuniversity.edu.ng', 'lecturer123', 'role_lecturer', 'Prof. Aisha', 'Garba', None, None, 'dept_economics', 'fac_social_sciences'),
        ('user_lecturer_6', 'dr.yusuf', 'yusuf@newgateuniversity.edu.ng', 'lecturer123', 'role_lecturer', 'Dr. Yusuf', 'Abdullahi', None, None, 'dept_accounting', 'fac_management'),

        # Students from different departments and levels
        ('user_student_1', 'student1', 'ahmed.musa@student.newgateuniversity.edu.ng', 'student123', 'role_student', 'Ahmed', 'Musa', 'level_undergraduate', 'year_200l', 'dept_computer_science', 'fac_engineering'),
        ('user_student_2', 'student2', 'fatima.ibrahim@student.newgateuniversity.edu.ng', 'student123', 'role_student', 'Fatima', 'Ibrahim', 'level_undergraduate', 'year_300l', 'dept_computer_science', 'fac_engineering'),
        ('user_student_3', 'student3', 'usman.ali@student.newgateuniversity.edu.ng', 'student123', 'role_student', 'Usman', 'Ali', 'level_undergraduate', 'year_100l', 'dept_electrical_engineering', 'fac_engineering'),
        ('user_student_4', 'student4', 'aisha.hassan@student.newgateuniversity.edu.ng', 'student123', 'role_student', 'Aisha', 'Hassan', 'level_undergraduate', 'year_400l', 'dept_mathematics', 'fac_science'),
        ('user_student_5', 'student5', 'ibrahim.garba@student.newgateuniversity.edu.ng', 'student123', 'role_student', 'Ibrahim', 'Garba', 'level_undergraduate', 'year_200l', 'dept_economics', 'fac_social_sciences'),
        ('user_student_6', 'student6', 'zainab.umar@student.newgateuniversity.edu.ng', 'student123', 'role_student', 'Zainab', 'Umar', 'level_undergraduate', 'year_300l', 'dept_accounting', 'fac_management'),
        ('user_student_7', 'student7', 'mohammed.bello@student.newgateuniversity.edu.ng', 'student123', 'role_student', 'Mohammed', 'Bello', 'level_undergraduate', 'year_100l', 'dept_mechanical_engineering', 'fac_engineering'),
        ('user_student_8', 'student8', 'hauwa.abdullahi@student.newgateuniversity.edu.ng', 'student123', 'role_student', 'Hauwa', 'Abdullahi', 'level_undergraduate', 'year_200l', 'dept_chemistry', 'fac_science'),
        ('user_student_9', 'student9', 'sani.mohammed@student.newgateuniversity.edu.ng', 'student123', 'role_student', 'Sani', 'Mohammed', 'level_masters', 'year_msc1', 'dept_computer_science', 'fac_engineering'),
        ('user_student_10', 'student10', 'khadija.yusuf@student.newgateuniversity.edu.ng', 'student123', 'role_student', 'Khadija', 'Yusuf', 'level_undergraduate', 'year_400l', 'dept_business_admin', 'fac_management'),
    ]

    for user_id, username, email, password, role_id, first_name, last_name, level_id, year_id, dept_id, fac_id in users:
        password_hash = hash_password(password)
        cursor.execute('''
            INSERT INTO users (id, username, email, password_hash, role_id, first_name, last_name,
                             level_id, year_id, department_id, faculty_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (user_id, username, email, password_hash, role_id, first_name, last_name,
              level_id, year_id, dept_id, fac_id, now, now))
    
    # Realistic courses across different departments
    courses = [
        # Computer Science Courses
        ('course_csc101', 'Introduction to Computer Science', 'CSC101', 'Basic concepts of computer science and programming', 'level_undergraduate', 'year_100l', 'dept_computer_science', 'fac_engineering', 'user_lecturer_1'),
        ('course_csc201', 'Data Structures and Algorithms', 'CSC201', 'Fundamental data structures and algorithmic techniques', 'level_undergraduate', 'year_200l', 'dept_computer_science', 'fac_engineering', 'user_lecturer_1'),
        ('course_csc301', 'Database Management Systems', 'CSC301', 'Design and implementation of database systems', 'level_undergraduate', 'year_300l', 'dept_computer_science', 'fac_engineering', 'user_lecturer_2'),
        ('course_csc401', 'Software Engineering', 'CSC401', 'Principles and practices of software development', 'level_undergraduate', 'year_400l', 'dept_computer_science', 'fac_engineering', 'user_lecturer_2'),
        ('course_csc501', 'Artificial Intelligence', 'CSC501', 'Introduction to AI concepts and machine learning', 'level_masters', 'year_msc1', 'dept_computer_science', 'fac_engineering', 'user_lecturer_2'),

        # Mathematics Courses
        ('course_mth101', 'General Mathematics I', 'MTH101', 'Basic mathematical concepts and calculus', 'level_undergraduate', 'year_100l', 'dept_mathematics', 'fac_science', 'user_lecturer_3'),
        ('course_mth201', 'Linear Algebra', 'MTH201', 'Vector spaces, matrices, and linear transformations', 'level_undergraduate', 'year_200l', 'dept_mathematics', 'fac_science', 'user_lecturer_3'),
        ('course_mth301', 'Real Analysis', 'MTH301', 'Advanced calculus and real number theory', 'level_undergraduate', 'year_300l', 'dept_mathematics', 'fac_science', 'user_lecturer_3'),
        ('course_mth401', 'Complex Analysis', 'MTH401', 'Functions of complex variables', 'level_undergraduate', 'year_400l', 'dept_mathematics', 'fac_science', 'user_lecturer_3'),

        # Electrical Engineering Courses
        ('course_eee101', 'Circuit Analysis I', 'EEE101', 'Basic electrical circuit analysis', 'level_undergraduate', 'year_100l', 'dept_electrical_engineering', 'fac_engineering', 'user_lecturer_4'),
        ('course_eee201', 'Electronics I', 'EEE201', 'Semiconductor devices and basic electronics', 'level_undergraduate', 'year_200l', 'dept_electrical_engineering', 'fac_engineering', 'user_lecturer_4'),
        ('course_eee301', 'Digital Signal Processing', 'EEE301', 'Processing of digital signals and systems', 'level_undergraduate', 'year_300l', 'dept_electrical_engineering', 'fac_engineering', 'user_lecturer_4'),

        # Economics Courses
        ('course_eco101', 'Principles of Economics I', 'ECO101', 'Introduction to microeconomics', 'level_undergraduate', 'year_100l', 'dept_economics', 'fac_social_sciences', 'user_lecturer_5'),
        ('course_eco201', 'Macroeconomics', 'ECO201', 'National income, employment, and monetary policy', 'level_undergraduate', 'year_200l', 'dept_economics', 'fac_social_sciences', 'user_lecturer_5'),
        ('course_eco301', 'Development Economics', 'ECO301', 'Economic development theories and policies', 'level_undergraduate', 'year_300l', 'dept_economics', 'fac_social_sciences', 'user_lecturer_5'),

        # Accounting Courses
        ('course_acc101', 'Financial Accounting I', 'ACC101', 'Basic principles of financial accounting', 'level_undergraduate', 'year_100l', 'dept_accounting', 'fac_management', 'user_lecturer_6'),
        ('course_acc201', 'Cost Accounting', 'ACC201', 'Cost determination and control systems', 'level_undergraduate', 'year_200l', 'dept_accounting', 'fac_management', 'user_lecturer_6'),
        ('course_acc301', 'Advanced Financial Accounting', 'ACC301', 'Complex accounting transactions and standards', 'level_undergraduate', 'year_300l', 'dept_accounting', 'fac_management', 'user_lecturer_6'),
        ('course_acc401', 'Auditing and Assurance', 'ACC401', 'Principles and practices of auditing', 'level_undergraduate', 'year_400l', 'dept_accounting', 'fac_management', 'user_lecturer_6'),
    ]

    for course_id, name, code, description, level_id, year_id, dept_id, fac_id, lecturer_id in courses:
        cursor.execute('''
            INSERT INTO courses (id, name, code, description, level_id, year_id, department_id, faculty_id, lecturer_id, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (course_id, name, code, description, level_id, year_id, dept_id, fac_id, lecturer_id, now, now))

    # Student enrollments (realistic course registrations)
    enrollments = [
        # Ahmed Musa (200L Computer Science) - enrolled in 200L courses
        ('user_student_1', 'course_csc201'),
        ('user_student_1', 'course_mth201'),

        # Fatima Ibrahim (300L Computer Science) - enrolled in 300L courses
        ('user_student_2', 'course_csc301'),
        ('user_student_2', 'course_mth301'),

        # Usman Ali (100L Electrical Engineering) - enrolled in 100L courses
        ('user_student_3', 'course_eee101'),
        ('user_student_3', 'course_mth101'),

        # Aisha Hassan (400L Mathematics) - enrolled in 400L courses
        ('user_student_4', 'course_mth401'),

        # Ibrahim Garba (200L Economics) - enrolled in 200L courses
        ('user_student_5', 'course_eco201'),

        # Zainab Umar (300L Accounting) - enrolled in 300L courses
        ('user_student_6', 'course_acc301'),

        # Mohammed Bello (100L Mechanical Engineering) - enrolled in 100L courses
        ('user_student_7', 'course_mth101'),

        # Hauwa Abdullahi (200L Chemistry) - enrolled in 200L courses
        ('user_student_8', 'course_mth201'),

        # Sani Mohammed (MSc Computer Science) - enrolled in postgraduate course
        ('user_student_9', 'course_csc501'),

        # Khadija Yusuf (400L Business Administration) - enrolled in 400L courses
        ('user_student_10', 'course_acc401'),
    ]

    for user_id, course_id in enrollments:
        cursor.execute('''
            INSERT INTO user_courses (id, user_id, course_id, enrolled_at)
            VALUES (?, ?, ?, ?)
        ''', (str(uuid.uuid4()), user_id, course_id, now))

    # Sample announcements
    announcements = [
        ('ann_1', 'Welcome to New Academic Session 2024/2025', 'Welcome to the new academic session. All students are expected to register their courses online.', 'user_admin_1', 'role_student,role_lecturer', None),
        ('ann_2', 'CSC301 Database Lab Schedule', 'Database Management Systems lab sessions will be held every Tuesday and Thursday from 2-4 PM in Computer Lab 1.', 'user_lecturer_2', 'role_student', 'course_csc301'),
        ('ann_3', 'Faculty of Engineering Orientation', 'All new students in the Faculty of Engineering are invited to the orientation program on Monday, 9 AM at the Engineering Auditorium.', 'user_admin_1', 'role_student', None),
        ('ann_4', 'Mathematics Department Seminar', 'Guest lecture on "Applications of Real Analysis in Engineering" by Prof. Adamu from ABU. Date: Friday, 10 AM, Math Lecture Theatre.', 'user_lecturer_3', 'role_student,role_lecturer', None),
    ]

    for ann_id, title, content, author_id, target_roles, target_courses in announcements:
        cursor.execute('''
            INSERT INTO announcements (id, title, content, author_id, target_roles, target_courses, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (ann_id, title, content, author_id, target_roles, target_courses, now, now))
    
    # Commit and close
    conn.commit()
    conn.close()
    
    print("✅ Database created successfully!")
    print(f"📁 Database location: {os.path.abspath(db_path)}")
    print("\n🔑 Login credentials:")
    print("Super Admin: superadmin / admin123")
    print("Admin: admin / admin123")
    print("Registrar: registrar / admin123")
    print("Lecturers: dr.adebayo, prof.hassan, dr.fatima, dr.ibrahim, prof.aisha, dr.yusuf / lecturer123")
    print("Students: student1, student2, student3, etc. / student123")
    print("\n📊 Database Statistics:")
    print(f"- 7 Faculties")
    print(f"- 24 Departments")
    print(f"- 4 Academic Levels")
    print(f"- 12 Academic Years")
    print(f"- {len(users)} Users")
    print(f"- {len(courses)} Courses")
    print(f"- {len(enrollments)} Course Enrollments")
    print(f"- {len(announcements)} Announcements")

if __name__ == "__main__":
    create_database()
