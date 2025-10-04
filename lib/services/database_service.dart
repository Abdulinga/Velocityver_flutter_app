import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../utils/database_constants.dart';
import 'package:sqflite/sqflite.dart';


class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Reset database (for debugging)
  Future<void> resetDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DatabaseConstants.databaseName);

    try {
      await deleteDatabase(path);
      debugPrint('🗑️ Database deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting database: $e');
    }

    // Reinitialize
    _database = await _initDatabase();
    debugPrint('🔄 Database reset and reinitialized');
  }

  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, DatabaseConstants.databaseName);

      debugPrint('🗄️ Database path: $path');

      final dbFile = File(path);
      final exists = await dbFile.exists();
      debugPrint('🗄️ Database file exists: $exists');

      debugPrint('📂 Opening/creating database...');

      final db = await openDatabase(
        path,
        version: DatabaseConstants.databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      await _initializeChatTables(db);
      await debugDatabaseContents();

      debugPrint('✅ Database opened successfully');
      return db;
    } catch (e) {
      debugPrint('❌ Database initialization failed: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      // Create all tables in dependency order
      await db.execute(DatabaseConstants.rolesCreateTable);
      await db.execute(DatabaseConstants.facultiesCreateTable);
      await db.execute(DatabaseConstants.departmentsCreateTable);
      await db.execute(DatabaseConstants.levelsCreateTable);
      await db.execute(DatabaseConstants.yearsCreateTable);
      await db.execute(DatabaseConstants.usersCreateTable);
      await db.execute(DatabaseConstants.coursesCreateTable);
      await db.execute(DatabaseConstants.filesCreateTable);
      await db.execute(DatabaseConstants.announcementsCreateTable);
      await db.execute(DatabaseConstants.userCoursesCreateTable);
      await db.execute(DatabaseConstants.syncMetadataCreateTable);

      // Create enrollments table for course enrollments
      await db.execute('''
        CREATE TABLE IF NOT EXISTS enrollments (
          id TEXT PRIMARY KEY,
          student_id TEXT NOT NULL,
          course_id TEXT NOT NULL,
          status TEXT DEFAULT 'active',
          enrolled_at TEXT NOT NULL,
          enrolled_by TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (student_id) REFERENCES users (id),
          FOREIGN KEY (course_id) REFERENCES courses (id),
          FOREIGN KEY (enrolled_by) REFERENCES users (id),
          UNIQUE(student_id, course_id)
        )
      ''');

      // Create indexes for performance
      for (String index in DatabaseConstants.indexes) {
        await db.execute(index);
      }

      // Additional indexes for enrollments
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_enrollments_student ON enrollments (student_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_enrollments_course ON enrollments (course_id)',
      );

      // Insert default data
      await _insertDefaultData(db);

      debugPrint('✅ Database tables and data created successfully');
    } catch (e) {
      debugPrint('❌ Error in _onCreate: $e');
      rethrow;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      debugPrint(
        '🔄 Upgrading database from version $oldVersion to $newVersion',
      );

      if (oldVersion < 2 && newVersion >= 2) {
        await _upgradeToVersion2(db);
      }

      if (oldVersion < 3 && newVersion >= 3) {
        await _upgradeToVersion3(db);
      }

      if (oldVersion < 4 && newVersion >= 4) {
        await _upgradeToVersion4(db);
      }

      debugPrint('✅ Database upgrade completed');
    } catch (e) {
      debugPrint('❌ Error during database upgrade: $e');
      rethrow;
    }
  }

  Future<void> _upgradeToVersion2(Database db) async {
    // Migration from version 1 to 2: Add missing columns to faculties table
    await db.execute('ALTER TABLE faculties ADD COLUMN code TEXT');
    await db.execute('ALTER TABLE faculties ADD COLUMN deanId TEXT');
    await db.execute(
      'ALTER TABLE faculties ADD COLUMN isActive INTEGER NOT NULL DEFAULT 1',
    );

    // Update existing faculties with default codes
    final faculties = await db.query('faculties');
    for (var faculty in faculties) {
      String code = _generateFacultyCode(faculty['name'] as String);
      await db.update(
        'faculties',
        {'code': code},
        where: 'id = ?',
        whereArgs: [faculty['id']],
      );
    }
  }

  Future<void> _upgradeToVersion3(Database db) async {
    // Migration from version 2 to 3: Add missing columns to departments, levels, years tables

    // Departments table
    await db.execute('ALTER TABLE departments ADD COLUMN code TEXT');
    await db.execute('ALTER TABLE departments ADD COLUMN hodId TEXT');
    await db.execute(
      'ALTER TABLE departments ADD COLUMN isActive INTEGER NOT NULL DEFAULT 1',
    );

    // Levels table
    await db.execute('ALTER TABLE levels ADD COLUMN code TEXT');
    await db.execute(
      'ALTER TABLE levels ADD COLUMN order_num INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute(
      'ALTER TABLE levels ADD COLUMN isActive INTEGER NOT NULL DEFAULT 1',
    );

    // Years table
    await db.execute('ALTER TABLE years ADD COLUMN code TEXT');
    await db.execute(
      'ALTER TABLE years ADD COLUMN order_num INTEGER NOT NULL DEFAULT 1',
    );
    await db.execute(
      'ALTER TABLE years ADD COLUMN isActive INTEGER NOT NULL DEFAULT 1',
    );

    // Update existing departments with codes
    final departments = await db.query('departments');
    for (var dept in departments) {
      String code = _generateDepartmentCode(dept['name'] as String);
      await db.update(
        'departments',
        {'code': code},
        where: 'id = ?',
        whereArgs: [dept['id']],
      );
    }

    // Update existing levels
    final levels = await db.query('levels');
    for (int i = 0; i < levels.length; i++) {
      var level = levels[i];
      String code = _generateLevelCode(level['name'] as String);
      await db.update(
        'levels',
        {'code': code, 'order_num': i + 1},
        where: 'id = ?',
        whereArgs: [level['id']],
      );
    }

    // Update existing years
    final years = await db.query('years');
    for (int i = 0; i < years.length; i++) {
      var year = years[i];
      String code = _generateYearCode(year['name'] as String, i);
      await db.update(
        'years',
        {'code': code, 'order_num': i + 1},
        where: 'id = ?',
        whereArgs: [year['id']],
      );
    }
  }

  Future<void> _upgradeToVersion4(Database db) async {
    // Migration from version 3 to 4: Add is_active column to roles table
    await db.execute(
      'ALTER TABLE roles ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
    );
  }

  String _generateFacultyCode(String name) {
    if (name.toLowerCase().contains('engineering')) return 'ENG';
    if (name.toLowerCase().contains('science')) return 'SCI';
    if (name.toLowerCase().contains('arts')) return 'ART';
    if (name.toLowerCase().contains('business')) return 'BUS';
    if (name.toLowerCase().contains('medicine')) return 'MED';

    // Generate code from first 3 letters
    return name.replaceAll(' ', '').substring(0, 3).toUpperCase();
  }

  String _generateDepartmentCode(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('computer science')) return 'CS';
    if (lowerName.contains('electrical')) return 'EE';
    if (lowerName.contains('mechanical')) return 'ME';
    if (lowerName.contains('civil')) return 'CE';
    if (lowerName.contains('mathematics')) return 'MATH';
    if (lowerName.contains('physics')) return 'PHYS';
    if (lowerName.contains('chemistry')) return 'CHEM';
    if (lowerName.contains('biology')) return 'BIO';

    // Generate code from first 2-4 letters
    final cleanName = name.replaceAll(' ', '');
    final length = cleanName.length >= 4 ? 4 : cleanName.length;
    return cleanName.substring(0, length).toUpperCase();
  }

  String _generateLevelCode(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('undergraduate')) return 'UG';
    if (lowerName.contains('graduate') && !lowerName.contains('post'))
      return 'GR';
    if (lowerName.contains('postgraduate')) return 'PG';
    if (lowerName.contains('masters')) return 'MS';
    if (lowerName.contains('doctorate') || lowerName.contains('phd'))
      return 'PHD';

    // Generate from first 2 letters
    return name.replaceAll(' ', '').substring(0, 2).toUpperCase();
  }

  String _generateYearCode(String name, int index) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('1') || lowerName.contains('first')) return 'Y1';
    if (lowerName.contains('2') || lowerName.contains('second')) return 'Y2';
    if (lowerName.contains('3') || lowerName.contains('third')) return 'Y3';
    if (lowerName.contains('4') || lowerName.contains('fourth')) return 'Y4';
    if (lowerName.contains('5') || lowerName.contains('fifth')) return 'Y5';

    // Generate from index
    return 'Y${index + 1}';
  }

  Future<void> _insertDefaultData(Database db) async {
    try {
      // Insert in dependency order
      await _insertDefaultRoles(db);
      await _insertDefaultAcademicStructure(db);
      await _insertDefaultUsers(db);
      await _insertDefaultCourses(db);
      await _insertDefaultEnrollments(db);
      await _insertDefaultAnnouncements(db);

      debugPrint('✅ Default data inserted successfully');
    } catch (e) {
      debugPrint('❌ Error inserting default data: $e');
      rethrow;
    }
  }

  Future<void> _insertDefaultRoles(Database db) async {
    for (var roleData in DatabaseConstants.defaultRoles) {
      try {
        // Parse permissions JSON string
        List<String> permissionsList = [];
        final permissionsRaw = roleData['permissions'];

        if (permissionsRaw is String) {
          try {
            final decoded = jsonDecode(permissionsRaw) as List;
            permissionsList = decoded.cast<String>();
          } catch (e) {
            debugPrint(
              'Error parsing permissions for role ${roleData['name']}: $e',
            );
          }
        } else if (permissionsRaw is List) {
          permissionsList = permissionsRaw.cast<String>();
        }

        final role = Role(
          id: roleData['id'] as String,
          name: roleData['name'] as String,
          description: roleData['description'] as String,
          permissions: permissionsList,
        );

        await db.insert(DatabaseConstants.rolesTable, role.toJson());
        debugPrint('✅ Created role: ${role.name}');
      } catch (e) {
        debugPrint('❌ Failed to create role ${roleData['name']}: $e');
      }
    }
  }

  Future<void> _insertDefaultAcademicStructure(Database db) async {
    // Default faculties
    final faculties = [
      Faculty(
        id: 'fac_engineering',
        name: 'Faculty of Engineering',
        code: 'ENG',
      ),
      Faculty(id: 'fac_science', name: 'Faculty of Science', code: 'SCI'),
      Faculty(id: 'fac_arts', name: 'Faculty of Arts', code: 'ART'),
      Faculty(id: 'fac_business', name: 'Faculty of Business', code: 'BUS'),
    ];

    for (var faculty in faculties) {
      try {
        await db.insert(DatabaseConstants.facultiesTable, faculty.toJson());
        debugPrint('✅ Created faculty: ${faculty.name}');
      } catch (e) {
        debugPrint('❌ Failed to create faculty ${faculty.name}: $e');
      }
    }

    // Default departments
    final departments = [
      Department(
        id: 'dept_cs',
        name: 'Computer Science',
        code: 'CS',
        facultyId: 'fac_engineering',
      ),
      Department(
        id: 'dept_ee',
        name: 'Electrical Engineering',
        code: 'EE',
        facultyId: 'fac_engineering',
      ),
      Department(
        id: 'dept_me',
        name: 'Mechanical Engineering',
        code: 'ME',
        facultyId: 'fac_engineering',
      ),
      Department(
        id: 'dept_math',
        name: 'Mathematics',
        code: 'MATH',
        facultyId: 'fac_science',
      ),
      Department(
        id: 'dept_physics',
        name: 'Physics',
        code: 'PHYS',
        facultyId: 'fac_science',
      ),
      Department(
        id: 'dept_english',
        name: 'English Literature',
        code: 'ENG',
        facultyId: 'fac_arts',
      ),
    ];

    for (var department in departments) {
      try {
        await db.insert(
          DatabaseConstants.departmentsTable,
          department.toJson(),
        );
        debugPrint('✅ Created department: ${department.name}');
      } catch (e) {
        debugPrint('❌ Failed to create department ${department.name}: $e');
      }
    }

    // Default levels
    final levels = [
      Level(
        id: 'level_undergraduate',
        name: 'Undergraduate',
        code: 'UG',
        order: 1,
      ),
      Level(id: 'level_graduate', name: 'Graduate', code: 'GR', order: 2),
      Level(
        id: 'level_postgraduate',
        name: 'Postgraduate',
        code: 'PG',
        order: 3,
      ),
    ];

    for (var level in levels) {
      try {
        await db.insert(DatabaseConstants.levelsTable, level.toJson());
        debugPrint('✅ Created level: ${level.name}');
      } catch (e) {
        debugPrint('❌ Failed to create level ${level.name}: $e');
      }
    }

    // Default years
    final years = [
      Year(id: 'year_1', name: 'Year 1', code: 'Y1', order: 1),
      Year(id: 'year_2', name: 'Year 2', code: 'Y2', order: 2),
      Year(id: 'year_3', name: 'Year 3', code: 'Y3', order: 3),
      Year(id: 'year_4', name: 'Year 4', code: 'Y4', order: 4),
    ];

    for (var year in years) {
      try {
        await db.insert(DatabaseConstants.yearsTable, year.toJson());
        debugPrint('✅ Created year: ${year.name}');
      } catch (e) {
        debugPrint('❌ Failed to create year ${year.name}: $e');
      }
    }
  }

  Future<void> _insertDefaultUsers(Database db) async {
    final defaultUsers = [
      {
        'id': 'user_super_admin',
        'username': 'superadmin',
        'email': 'superadmin@velocityver.com',
        'password': 'admin123',
        'role_id': 'role_super_admin',
        'first_name': 'Super',
        'last_name': 'Admin',
      },
      {
        'id': 'user_admin',
        'username': 'admin',
        'email': 'admin@velocityver.com',
        'password': 'admin123',
        'role_id': 'role_admin',
        'first_name': 'Admin',
        'last_name': 'User',
      },
      {
        'id': 'user_lecturer_cs',
        'username': 'lecturer.cs',
        'email': 'john.doe@velocityver.com',
        'password': 'lecturer123',
        'role_id': 'role_lecturer',
        'first_name': 'John',
        'last_name': 'Doe',
        'department_id': 'dept_cs',
        'faculty_id': 'fac_engineering',
      },
      {
        'id': 'user_lecturer_ee',
        'username': 'lecturer.ee',
        'email': 'jane.smith@velocityver.com',
        'password': 'lecturer123',
        'role_id': 'role_lecturer',
        'first_name': 'Jane',
        'last_name': 'Smith',
        'department_id': 'dept_ee',
        'faculty_id': 'fac_engineering',
      },
      {
        'id': 'user_student_1',
        'username': 'student1',
        'email': 'alice.johnson@student.velocityver.com',
        'password': 'student123',
        'role_id': 'role_student',
        'first_name': 'Alice',
        'last_name': 'Johnson',
        'level_id': 'level_undergraduate',
        'year_id': 'year_2',
        'department_id': 'dept_cs',
        'faculty_id': 'fac_engineering',
      },
      {
        'id': 'user_student_2',
        'username': 'student2',
        'email': 'bob.williams@student.velocityver.com',
        'password': 'student123',
        'role_id': 'role_student',
        'first_name': 'Bob',
        'last_name': 'Williams',
        'level_id': 'level_undergraduate',
        'year_id': 'year_1',
        'department_id': 'dept_ee',
        'faculty_id': 'fac_engineering',
      },
      {
        'id': 'user_student_3',
        'username': 'student3',
        'email': 'carol.brown@student.velocityver.com',
        'password': 'student123',
        'role_id': 'role_student',
        'first_name': 'Carol',
        'last_name': 'Brown',
        'level_id': 'level_undergraduate',
        'year_id': 'year_3',
        'department_id': 'dept_cs',
        'faculty_id': 'fac_engineering',
      },
    ];

    for (var userData in defaultUsers) {
      try {
        final hashedPassword = _hashPassword(userData['password'] as String);

        final user = User(
          id: userData['id'] as String,
          username: userData['username'] as String,
          email: userData['email'] as String,
          passwordHash: hashedPassword,
          roleId: userData['role_id'] as String,
          firstName: userData['first_name'] as String,
          lastName: userData['last_name'] as String,
          levelId: userData['level_id'] as String?,
          yearId: userData['year_id'] as String?,
          departmentId: userData['department_id'] as String?,
          facultyId: userData['faculty_id'] as String?,
          isActive: true,
        );

        await db.insert(DatabaseConstants.usersTable, user.toJson());
        debugPrint('✅ Created user: ${user.username} (${user.roleId})');
      } catch (e) {
        debugPrint('❌ Failed to create user ${userData['username']}: $e');
      }
    }
  }

  Future<void> _insertDefaultCourses(Database db) async {
    final courses = [
      Course(
        id: 'course_cs101',
        name: 'Introduction to Computer Science',
        code: 'CS101',
        description:
            'Basic concepts of computer science and programming fundamentals',
        levelId: 'level_undergraduate',
        yearId: 'year_1',
        departmentId: 'dept_cs',
        facultyId: 'fac_engineering',
        lecturerId: 'user_lecturer_cs',
      ),
      Course(
        id: 'course_cs201',
        name: 'Data Structures and Algorithms',
        code: 'CS201',
        description: 'Advanced programming concepts and algorithm design',
        levelId: 'level_undergraduate',
        yearId: 'year_2',
        departmentId: 'dept_cs',
        facultyId: 'fac_engineering',
        lecturerId: 'user_lecturer_cs',
      ),
      Course(
        id: 'course_cs301',
        name: 'Software Engineering',
        code: 'CS301',
        description:
            'Software development methodologies and project management',
        levelId: 'level_undergraduate',
        yearId: 'year_3',
        departmentId: 'dept_cs',
        facultyId: 'fac_engineering',
        lecturerId: 'user_lecturer_cs',
      ),
      Course(
        id: 'course_ee101',
        name: 'Electrical Engineering Fundamentals',
        code: 'EE101',
        description:
            'Basic principles of electrical engineering and circuit analysis',
        levelId: 'level_undergraduate',
        yearId: 'year_1',
        departmentId: 'dept_ee',
        facultyId: 'fac_engineering',
        lecturerId: 'user_lecturer_ee',
      ),
      Course(
        id: 'course_ee201',
        name: 'Digital Electronics',
        code: 'EE201',
        description: 'Digital logic design and electronic systems',
        levelId: 'level_undergraduate',
        yearId: 'year_2',
        departmentId: 'dept_ee',
        facultyId: 'fac_engineering',
        lecturerId: 'user_lecturer_ee',
      ),
    ];

    for (var course in courses) {
      try {
        await db.insert(DatabaseConstants.coursesTable, course.toJson());
        debugPrint('✅ Created course: ${course.code} - ${course.name}');
      } catch (e) {
        debugPrint('❌ Failed to create course ${course.code}: $e');
      }
    }
  }

  Future<void> _insertDefaultEnrollments(Database db) async {
    final enrollments = [
      // Student 1 (Alice) - Year 2 CS student
      {'student_id': 'user_student_1', 'course_id': 'course_cs101'},
      {'student_id': 'user_student_1', 'course_id': 'course_cs201'},

      // Student 2 (Bob) - Year 1 EE student
      {'student_id': 'user_student_2', 'course_id': 'course_ee101'},
      {
        'student_id': 'user_student_2',
        'course_id': 'course_cs101',
      }, // Cross-department
      // Student 3 (Carol) - Year 3 CS student
      {'student_id': 'user_student_3', 'course_id': 'course_cs101'},
      {'student_id': 'user_student_3', 'course_id': 'course_cs201'},
      {'student_id': 'user_student_3', 'course_id': 'course_cs301'},
    ];

    for (var enrollment in enrollments) {
      try {
        await _createEnrollment(
          db,
          enrollment['student_id'] as String,
          enrollment['course_id'] as String,
        );
      } catch (e) {
        debugPrint('❌ Failed to create enrollment: $e');
      }
    }
  }

  Future<void> _createEnrollment(
    Database db,
    String studentId,
    String courseId,
  ) async {
    final enrollmentId = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    final enrollmentData = {
      'id': enrollmentId,
      'student_id': studentId,
      'course_id': courseId,
      'status': 'active',
      'enrolled_at': now,
      'enrolled_by': 'user_admin',
      'created_at': now,
      'updated_at': now,
    };

    await db.insert('enrollments', enrollmentData);

    // Also create user_course entry for compatibility
    final userCourse = UserCourse(userId: studentId, courseId: courseId);
    try {
      await db.insert(DatabaseConstants.userCoursesTable, userCourse.toJson());
    } catch (e) {
      // Ignore if already exists
      debugPrint('UserCourse entry may already exist: $e');
    }

    debugPrint('✅ Created enrollment: $studentId -> $courseId');
  }

  Future<void> _insertDefaultAnnouncements(Database db) async {
    final announcements = [
      Announcement(
        id: 'announcement_welcome',
        title: 'Welcome to the New Academic Year 2024-2025',
        content:
            'Welcome all students and faculty to the new academic year. We wish everyone a productive and successful semester ahead.',
        authorId: 'user_admin',
        targetRoles: ['Student', 'Lecturer'],
        isActive: true,
      ),
      Announcement(
        id: 'announcement_registration',
        title: 'Course Registration Deadline Extended',
        content:
            'Course registration deadline has been extended to Friday, September 15th. Please complete your registration before the deadline.',
        authorId: 'user_admin',
        targetRoles: ['Student'],
        isActive: true,
      ),
      Announcement(
        id: 'announcement_faculty',
        title: 'Monthly Faculty Meeting',
        content:
            'Monthly faculty meeting scheduled for Monday, September 11th at 2:00 PM in the Main Conference Room.',
        authorId: 'user_admin',
        targetRoles: ['Lecturer', 'Admin'],
        isActive: true,
      ),
    ];

    for (var announcement in announcements) {
      try {
        await db.insert(
          DatabaseConstants.announcementsTable,
          announcement.toJson(),
        );
        debugPrint('✅ Created announcement: ${announcement.title}');
      } catch (e) {
        debugPrint('❌ Failed to create announcement ${announcement.title}: $e');
      }
    }
  }

  /// Hash password using SHA-256 (consistent with AuthService)
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ============================================================================
  // USER AUTHENTICATION AND OPERATIONS
  // ============================================================================

  /// Authenticate user with username and password
  Future<User?> authenticateUser(String username, String password) async {
    try {
      final db = await database;
      final hashedPassword = _hashPassword(password);

      debugPrint('🔐 Authenticating user: $username');

      // Check if user exists
      final userCheck = await db.query(
        DatabaseConstants.usersTable,
        where: 'username = ? AND is_active = 1',
        whereArgs: [username],
      );

      if (userCheck.isEmpty) {
        debugPrint('❌ User $username not found or inactive');
        return null;
      }

      // Verify password
      final userData = userCheck.first;
      if (userData['password_hash'] != hashedPassword) {
        debugPrint('❌ Invalid password for user $username');
        return null;
      }

      debugPrint('✅ Authentication successful for $username');

      final user = User.fromJson(userData);
      // Load user's role and related data
      user.role = await getRoleById(user.roleId);
      if (user.levelId != null) user.level = await getLevelById(user.levelId!);
      if (user.yearId != null) user.year = await getYearById(user.yearId!);
      if (user.departmentId != null)
        user.department = await getDepartmentById(user.departmentId!);
      if (user.facultyId != null)
        user.faculty = await getFacultyById(user.facultyId!);

      return user;
    } catch (e) {
      debugPrint('❌ Error in authenticateUser: $e');
      return null;
    }
  }

  /// Get user by ID with related data loaded
  Future<User?> getUserById(String id) async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.usersTable,
        where: 'id = ? AND is_active = 1',
        whereArgs: [id],
      );

      if (result.isEmpty) return null;

      final user = User.fromJson(result.first);
      // Load related data
      user.role = await getRoleById(user.roleId);
      if (user.levelId != null) user.level = await getLevelById(user.levelId!);
      if (user.yearId != null) user.year = await getYearById(user.yearId!);
      if (user.departmentId != null)
        user.department = await getDepartmentById(user.departmentId!);
      if (user.facultyId != null)
        user.faculty = await getFacultyById(user.facultyId!);

      return user;
    } catch (e) {
      debugPrint('❌ Error in getUserById: $e');
      return null;
    }
  }

  /// Get all active users
Future<List<User>> getAllUsers() async {
  final db = await database;

  try {
    final response = await http.get(Uri.parse('http://192.168.1.155:5000/api/users'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonBody = jsonDecode(response.body);
      final List<dynamic> items = jsonBody['items'] ?? [];

      // Save/update into SQLite
      for (final u in items) {
        await db.insert(
          DatabaseConstants.usersTable,
          User.fromJson(u).toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      return items.map((u) => User.fromJson(u)).toList();
    } else {
      debugPrint('❌ Failed to fetch users from server: ${response.body}');
    }
  } catch (e) {
    debugPrint('⚠️ Server unavailable, falling back to local: $e');
  }

  // Fallback: load from local DB
  final local = await db.query(
    DatabaseConstants.usersTable,
    where: 'is_active = 1',
    orderBy: 'first_name, last_name',
  );
  return local.map((json) => User.fromJson(json)).toList();
}

/// Insert new user
Future<String> insertUser(User user) async {
  final db = await database;
  user.updateTimestamp();

  try {
    final response = await http.post(
      Uri.parse('http://192.168.1.155:5000/api/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(user.toJson()),
    );

    if (response.statusCode == 201) {
      final serverUser = User.fromJson(jsonDecode(response.body));

      await db.insert(
        DatabaseConstants.usersTable,
        serverUser.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('✅ User created on server: ${serverUser.username}');
      return serverUser.id;
    } else {
      throw Exception('Server error: ${response.body}');
    }
  } catch (e) {
    // Offline fallback
    await db.insert(DatabaseConstants.usersTable, user.toJson());
    await _addSyncMetadata(
      DatabaseConstants.usersTable,
      user.id,
      SyncAction.create,
      user.toJson(),
    );
    debugPrint('⚠️ Saved user locally (offline mode): ${user.username}');
    return user.id;
  }
}

/// Update existing user
Future<void> updateUser(User user) async {
  final db = await database;
  user.updateTimestamp();

  try {
    final response = await http.put(
      Uri.parse('http://192.168.1.155:5000/api/users/${user.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(user.toJson()),
    );

    if (response.statusCode == 200) {
      await db.update(
        DatabaseConstants.usersTable,
        user.toJson(),
        where: 'id = ?',
        whereArgs: [user.id],
      );

      debugPrint('✅ User updated on server: ${user.username}');
    } else {
      throw Exception('Server error: ${response.body}');
    }
  } catch (e) {
    // Offline fallback
    await db.update(
      DatabaseConstants.usersTable,
      user.toJson(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
    await _addSyncMetadata(
      DatabaseConstants.usersTable,
      user.id,
      SyncAction.update,
      user.toJson(),
    );
    debugPrint('⚠️ Updated user locally (offline mode): ${user.username}');
  }
}

/// Soft delete user
Future<void> deleteUser(String id) async {
  final db = await database;

  try {
    final response = await http.delete(Uri.parse('http://192.168.1.155:5000/api/users/$id'));

    if (response.statusCode == 200) {
      await db.update(
        DatabaseConstants.usersTable,
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );

      debugPrint('✅ User deleted on server: $id');
    } else {
      throw Exception('Server error: ${response.body}');
    }
  } catch (e) {
    // Offline fallback
    await db.update(
      DatabaseConstants.usersTable,
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _addSyncMetadata(
      DatabaseConstants.usersTable,
      id,
      SyncAction.update,
      {'is_active': 0},
    );
    debugPrint('⚠️ Deleted user locally (offline mode): $id');
  }
}

  // ============================================================================
  // ROLE OPERATIONS
  // ============================================================================

  /// Get role by ID
  Future<Role?> getRoleById(String id) async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.rolesTable,
        where: 'id = ?',
        whereArgs: [id],
      );

      return result.isNotEmpty ? Role.fromJson(result.first) : null;
    } catch (e) {
      debugPrint('❌ Error getting role: $e');
      return null;
    }
  }

  /// Get all active roles
  Future<List<Role>> getAllRoles() async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.rolesTable,
        orderBy: 'name',
      );
      return result.map((json) => Role.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error getting roles: $e');
      return [];
    }
  }

  // ============================================================================
  // FACULTY OPERATIONS
  // ============================================================================

  /// Get faculty by ID
  Future<Faculty?> getFacultyById(String id) async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.facultiesTable,
        where: 'id = ?',
        whereArgs: [id],
      );

      return result.isNotEmpty ? Faculty.fromJson(result.first) : null;
    } catch (e) {
      debugPrint('❌ Error getting faculty: $e');
      return null;
    }
  }

  /// Get all active faculties
  Future<List<Faculty>> getAllFaculties() async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.facultiesTable,
        orderBy: 'name',
      );
      return result.map((json) => Faculty.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error getting faculties: $e');
      return [];
    }
  }

  /// Insert new faculty
  Future<String> insertFaculty(Faculty faculty) async {
    try {
      final db = await database;
      faculty.updateTimestamp();

      await db.insert(DatabaseConstants.facultiesTable, faculty.toJson());
      await _addSyncMetadata(
        DatabaseConstants.facultiesTable,
        faculty.id,
        SyncAction.create,
        faculty.toJson(),
      );

      debugPrint('✅ Faculty created: ${faculty.name}');
      return faculty.id;
    } catch (e) {
      debugPrint('❌ Error inserting faculty: $e');
      rethrow;
    }
  }

  /// Update existing faculty
  Future<void> updateFaculty(Faculty faculty) async {
    try {
      final db = await database;
      faculty.updateTimestamp();

      await db.update(
        DatabaseConstants.facultiesTable,
        faculty.toJson(),
        where: 'id = ?',
        whereArgs: [faculty.id],
      );
      await _addSyncMetadata(
        DatabaseConstants.facultiesTable,
        faculty.id,
        SyncAction.update,
        faculty.toJson(),
      );

      debugPrint('✅ Faculty updated: ${faculty.name}');
    } catch (e) {
      debugPrint('❌ Error updating faculty: $e');
      rethrow;
    }
  }

  /// Delete faculty
  Future<void> deleteFaculty(String id) async {
    try {
      final db = await database;
      await db.delete(
        DatabaseConstants.facultiesTable,
        where: 'id = ?',
        whereArgs: [id],
      );
      await _addSyncMetadata(
        DatabaseConstants.facultiesTable,
        id,
        SyncAction.delete,
        {},
      );

      debugPrint('✅ Faculty deleted: $id');
    } catch (e) {
      debugPrint('❌ Error deleting faculty: $e');
      rethrow;
    }
  }

  // ============================================================================
  // DEPARTMENT OPERATIONS
  // ============================================================================

  /// Get department by ID with faculty data
  Future<Department?> getDepartmentById(String id) async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.departmentsTable,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (result.isEmpty) return null;

      final department = Department.fromJson(result.first);
      department.faculty = await getFacultyById(department.facultyId);
      return department;
    } catch (e) {
      debugPrint('❌ Error getting department: $e');
      return null;
    }
  }

  /// Get departments by faculty ID
  Future<List<Department>> getDepartmentsByFaculty(String facultyId) async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.departmentsTable,
        where: 'faculty_id = ?',
        whereArgs: [facultyId],
        orderBy: 'name',
      );
      return result.map((json) => Department.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error getting departments by faculty: $e');
      return [];
    }
  }

  /// Get all departments
  Future<List<Department>> getAllDepartments() async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.departmentsTable,
        orderBy: 'name',
      );
      return result.map((json) => Department.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error getting all departments: $e');
      return [];
    }
  }

  /// Insert new department
  Future<String> insertDepartment(Department department) async {
    try {
      final db = await database;
      department.updateTimestamp();

      await db.insert(DatabaseConstants.departmentsTable, department.toJson());
      await _addSyncMetadata(
        DatabaseConstants.departmentsTable,
        department.id,
        SyncAction.create,
        department.toJson(),
      );

      debugPrint('✅ Department created: ${department.name}');
      return department.id;
    } catch (e) {
      debugPrint('❌ Error inserting department: $e');
      rethrow;
    }
  }

  /// Update existing department
  Future<void> updateDepartment(Department department) async {
    try {
      final db = await database;
      department.updateTimestamp();

      await db.update(
        DatabaseConstants.departmentsTable,
        department.toJson(),
        where: 'id = ?',
        whereArgs: [department.id],
      );
      await _addSyncMetadata(
        DatabaseConstants.departmentsTable,
        department.id,
        SyncAction.update,
        department.toJson(),
      );

      debugPrint('✅ Department updated: ${department.name}');
    } catch (e) {
      debugPrint('❌ Error updating department: $e');
      rethrow;
    }
  }

  /// Delete department
  Future<void> deleteDepartment(String id) async {
    try {
      final db = await database;
      await db.delete(
        DatabaseConstants.departmentsTable,
        where: 'id = ?',
        whereArgs: [id],
      );
      await _addSyncMetadata(
        DatabaseConstants.departmentsTable,
        id,
        SyncAction.delete,
        {},
      );

      debugPrint('✅ Department deleted: $id');
    } catch (e) {
      debugPrint('❌ Error deleting department: $e');
      rethrow;
    }
  }

  // ============================================================================
  // LEVEL OPERATIONS
  // ============================================================================

  /// Get level by ID
  Future<Level?> getLevelById(String id) async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.levelsTable,
        where: 'id = ?',
        whereArgs: [id],
      );

      return result.isNotEmpty ? Level.fromJson(result.first) : null;
    } catch (e) {
      debugPrint('❌ Error getting level: $e');
      return null;
    }
  }

  /// Get all levels ordered by order_num
  Future<List<Level>> getAllLevels() async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.levelsTable,
        orderBy: 'order_num, name',
      );
      return result.map((json) => Level.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error getting levels: $e');
      return [];
    }
  }

  // ============================================================================
  // YEAR OPERATIONS
  // ============================================================================

Future<void> insertYear(Year year) async {
  final db = await database;
  await db.insert(
    DatabaseConstants.yearsTable,
    year.toJson(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

  /// Get year by ID
  Future<Year?> getYearById(String id) async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.yearsTable,
        where: 'id = ?',
        whereArgs: [id],
      );

      return result.isNotEmpty ? Year.fromJson(result.first) : null;
    } catch (e) {
      debugPrint('❌ Error getting year: $e');
      return null;
    }
  }

  /// Get all years ordered by order_num
  Future<List<Year>> getAllYears() async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.yearsTable,
        orderBy: 'order_num, name',
      );
      return result.map((json) => Year.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error getting years: $e');
      return [];
    }
  }

  // ============================================================================
  // COURSE OPERATIONS
  // ============================================================================

  /// Get course by ID with related data loaded
  Future<Course?> getCourseById(String id) async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.coursesTable,
        where: 'id = ? AND is_active = 1',
        whereArgs: [id],
      );

      if (result.isEmpty) return null;

      final course = Course.fromJson(result.first);
      // Load related data
      course.level = await getLevelById(course.levelId);
      course.year = await getYearById(course.yearId);
      course.department = await getDepartmentById(course.departmentId);
      course.faculty = await getFacultyById(course.facultyId);
      if (course.lecturerId != null) {
        course.lecturer = await getUserById(course.lecturerId!);
      }
      return course;
    } catch (e) {
      debugPrint('❌ Error getting course: $e');
      return null;
    }
  }

  /// Get all active courses
  Future<List<Course>> getAllCourses() async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.coursesTable,
        where: 'is_active = 1',
        orderBy: 'code, name',
      );
      return result.map((json) => Course.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error getting all courses: $e');
      return [];
    }
  }

  /// Get courses assigned to a lecturer
  Future<List<Course>> getCoursesByLecturer(String lecturerId) async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.coursesTable,
        where: 'lecturer_id = ? AND is_active = 1',
        whereArgs: [lecturerId],
        orderBy: 'code, name',
      );
      return result.map((json) => Course.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error getting courses by lecturer: $e');
      return [];
    }
  }

  /// Get courses enrolled by a student
  Future<List<Course>> getCoursesByStudent(String studentId) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        '''
        SELECT DISTINCT c.* FROM ${DatabaseConstants.coursesTable} c
        INNER JOIN enrollments e ON c.id = e.course_id
        WHERE e.student_id = ? AND e.status = 'active' AND c.is_active = 1
        ORDER BY c.code, c.name
        ''',
        [studentId],
      );
      return result.map((json) => Course.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error getting courses by student: $e');
      return [];
    }
  }

  /// Insert new course
  Future<String> insertCourse(Course course) async {
    try {
      final db = await database;
      course.updateTimestamp();

      await db.insert(DatabaseConstants.coursesTable, course.toJson());
      await _addSyncMetadata(
        DatabaseConstants.coursesTable,
        course.id,
        SyncAction.create,
        course.toJson(),
      );

      debugPrint('✅ Course created: ${course.code} - ${course.name}');
      return course.id;
    } catch (e) {
      debugPrint('❌ Error inserting course: $e');
      rethrow;
    }
  }

  /// Update existing course
  Future<void> updateCourse(Course course) async {
    try {
      final db = await database;
      course.updateTimestamp();

      await db.update(
        DatabaseConstants.coursesTable,
        course.toJson(),
        where: 'id = ?',
        whereArgs: [course.id],
      );
      await _addSyncMetadata(
        DatabaseConstants.coursesTable,
        course.id,
        SyncAction.update,
        course.toJson(),
      );

      debugPrint('✅ Course updated: ${course.code}');
    } catch (e) {
      debugPrint('❌ Error updating course: $e');
      rethrow;
    }
  }

  /// Soft delete course (set is_active = 0)
  Future<void> deleteCourse(String id) async {
    try {
      final db = await database;
      await db.update(
        DatabaseConstants.coursesTable,
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _addSyncMetadata(
        DatabaseConstants.coursesTable,
        id,
        SyncAction.update,
        {'is_active': 0},
      );

      debugPrint('✅ Course deactivated: $id');
    } catch (e) {
      debugPrint('❌ Error deleting course: $e');
      rethrow;
    }
  }

  // ============================================================================
  // ENROLLMENT OPERATIONS
  // ============================================================================

  /// Enroll user in course (creates both enrollment and user_course entries)
  
  /// Unenroll user from course
  Future<void> unenrollUserFromCourse(String userId, String courseId) async {
    try {
      final db = await database;

      // Update enrollment status to inactive
      await db.update(
        'enrollments',
        {'status': 'inactive', 'updated_at': DateTime.now().toIso8601String()},
        where: 'student_id = ? AND course_id = ?',
        whereArgs: [userId, courseId],
      );

      // Also remove from user_courses table
      await db.delete(
        DatabaseConstants.userCoursesTable,
        where: 'user_id = ? AND course_id = ?',
        whereArgs: [userId, courseId],
      );

      await _addSyncMetadata(
        'enrollments',
        '$userId-$courseId',
        SyncAction.update,
        {'status': 'inactive'},
      );

      debugPrint('✅ User unenrolled: $userId -> $courseId');
    } catch (e) {
      debugPrint('❌ Error unenrolling user from course: $e');
      rethrow;
    }
  }

  /// Get students enrolled in a course
  Future<List<User>> getCourseStudents(String courseId) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        '''
        SELECT u.* FROM users u
        INNER JOIN enrollments e ON u.id = e.student_id
        WHERE e.course_id = ? AND e.status = 'active' AND u.is_active = 1
        ORDER BY u.first_name, u.last_name
        ''',
        [courseId],
      );

      final students = <User>[];
      for (final row in result) {
        final user = User.fromJson(row);
        user.role = await getRoleById(user.roleId);
        if (user.facultyId != null) {
          user.faculty = await getFacultyById(user.facultyId!);
        }
        if (user.departmentId != null) {
          user.department = await getDepartmentById(user.departmentId!);
        }
        students.add(user);
      }

      return students;
    } catch (e) {
      debugPrint('❌ Error getting course students: $e');
      return [];
    }
  }

  /// Create enrollment record
  Future<Enrollment> createEnrollment(Enrollment enrollment) async {
    try {
      final db = await database;

      if (enrollment.id.isEmpty) {
        enrollment.id = const Uuid().v4();
      }

      final now = DateTime.now();
      enrollment.createdAt = now;
      enrollment.updatedAt = now;

      await db.insert('enrollments', enrollment.toJson());

      // Create corresponding user_course entry
      final userCourse = UserCourse(
        userId: enrollment.studentId,
        courseId: enrollment.courseId,
      );
      try {
        await db.insert(
          DatabaseConstants.userCoursesTable,
          userCourse.toJson(),
        );
      } catch (e) {
        // Ignore if already exists
        debugPrint('UserCourse entry may already exist: $e');
      }

      debugPrint('✅ Enrollment created: ${enrollment.id}');
      return enrollment;
    } catch (e) {
      debugPrint('❌ Error creating enrollment: $e');
      rethrow;
    }
  }

  // ============================================================================
  // USER TYPE SPECIFIC OPERATIONS
  // ============================================================================

  /// Get all students (users with student role)
  Future<List<User>> getStudents() async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT u.* FROM users u
        INNER JOIN roles r ON u.role_id = r.id
        WHERE r.name = 'Student' AND u.is_active = 1
        ORDER BY u.first_name, u.last_name
      ''');

      final students = <User>[];
      for (final row in result) {
        final user = User.fromJson(row);
        user.role = await getRoleById(user.roleId);
        if (user.facultyId != null) {
          user.faculty = await getFacultyById(user.facultyId!);
        }
        if (user.departmentId != null) {
          user.department = await getDepartmentById(user.departmentId!);
        }
        students.add(user);
      }

      return students;
    } catch (e) {
      debugPrint('❌ Error getting students: $e');
      return [];
    }
  }

  /// Get courses assigned to a lecturer (alias for getCoursesByLecturer)
  Future<List<Course>> getLecturerCourses(String lecturerId) async {
  try {
    final response = await http.get(
      Uri.parse('http://192.168.1.119:5000/users/$lecturerId/courses'),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final List<dynamic> items = body is List ? body : (body['items'] ?? []);
      final courses = items.map((json) => Course.fromJson(json)).toList();

      // Save locally for offline use
      for (final course in courses) {
        await insertCourse(course);
      }

      return courses;
    } else {
      debugPrint('❌ Failed to fetch lecturer courses: ${response.body}');
      return await getAllCourses();
    }
  } catch (e) {
    debugPrint('⚠️ Error fetching lecturer courses: $e');
    return await getAllCourses();
  }
}
Future<List<Course>> getStudentCourses(String studentId) async {
  try {
    final response = await http.get(
      Uri.parse('http://192.168.1.119:5000/students/$studentId/courses'),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final List<dynamic> items = body is List ? body : (body['items'] ?? []);
      final courses = items.map((json) => Course.fromJson(json)).toList();

      // Save locally for offline use
      for (final course in courses) {
        await insertCourse(course);
      }

      return courses;
    } else {
      debugPrint('❌ Failed to fetch student courses: ${response.body}');
      return await getAllCourses();
    }
  } catch (e) {
    debugPrint('⚠️ Error fetching student courses: $e');
    return await getAllCourses();
  }
}

  Future<Map<String, dynamic>> getAdminStats() async {
    final response = await http.get(
      Uri.parse('http://192.168.1.155:5000/admin/stats'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load admin stats: ${response.body}');
    }
  }

  /// Get all lecturers and admins for chat functionality
  Future<List<User>> getLecturersAndAdmins() async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT u.* FROM users u
        INNER JOIN roles r ON u.role_id = r.id
        WHERE r.name IN ('Lecturer', 'Admin', 'Super Admin')
        AND u.is_active = 1
        ORDER BY u.first_name, u.last_name
      ''');

      final users = <User>[];
      for (final row in result) {
        final user = User.fromJson(row);
        user.role = await getRoleById(user.roleId);
        users.add(user);
      }

      return users;
    } catch (e) {
      debugPrint('❌ Error getting lecturers and admins: $e');
      return [];
    }
  }

  // ============================================================================
  // FILE OPERATIONS
  // ============================================================================

  /// Get file by ID with related data
  Future<FileModel?> getFileById(String id) async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.filesTable,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (result.isEmpty) return null;

      final file = FileModel.fromJson(result.first);
      if (file.courseId != null) {
        file.course = await getCourseById(file.courseId!);
      }
      file.uploader = await getUserById(file.uploadedBy);
      return file;
    } catch (e) {
      debugPrint('❌ Error getting file: $e');
      return null;
    }
  }

  /// Get files by course
  Future<List<FileModel>> getFilesByCourse(String courseId) async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.filesTable,
        where: 'course_id = ?',
        whereArgs: [courseId],
        orderBy: 'created_at DESC',
      );
      return result.map((json) => FileModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error getting files by course: $e');
      return [];
    }
  }

  /// Get files by uploader
  Future<List<FileModel>> getFilesByUploader(String uploaderId) async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.filesTable,
        where: 'uploaded_by = ?',
        whereArgs: [uploaderId],
        orderBy: 'created_at DESC',
      );
      return result.map((json) => FileModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error getting files by uploader: $e');
      return [];
    }
  }

  /// Get all files
  Future<List<FileModel>> getAllFiles() async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.filesTable,
        orderBy: 'created_at DESC',
      );
      return result.map((json) => FileModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error getting all files: $e');
      return [];
    }
  }

  /// Insert new file
  Future<String> insertFile(FileModel file) async {
    try {
      final db = await database;
      file.updateTimestamp();

      await db.insert(DatabaseConstants.filesTable, file.toJson());
      await _addSyncMetadata(
        DatabaseConstants.filesTable,
        file.id,
        SyncAction.create,
        file.toJson(),
      );

      debugPrint('✅ File created: ${file.name}');
      return file.id;
    } catch (e) {
      debugPrint('❌ Error inserting file: $e');
      rethrow;
    }
  }

  /// Update existing file
  Future<void> updateFile(FileModel file) async {
    try {
      final db = await database;
      file.updateTimestamp();

      await db.update(
        DatabaseConstants.filesTable,
        file.toJson(),
        where: 'id = ?',
        whereArgs: [file.id],
      );
      await _addSyncMetadata(
        DatabaseConstants.filesTable,
        file.id,
        SyncAction.update,
        file.toJson(),
      );

      debugPrint('✅ File updated: ${file.name}');
    } catch (e) {
      debugPrint('❌ Error updating file: $e');
      rethrow;
    }
  }

  /// Delete file
  Future<void> deleteFile(String id) async {
    try {
      final db = await database;
      await db.delete(
        DatabaseConstants.filesTable,
        where: 'id = ?',
        whereArgs: [id],
      );
      await _addSyncMetadata(
        DatabaseConstants.filesTable,
        id,
        SyncAction.delete,
        {},
      );

      debugPrint('✅ File deleted: $id');
    } catch (e) {
      debugPrint('❌ Error deleting file: $e');
      rethrow;
    }
  }

  // ============================================================================
  // ANNOUNCEMENT OPERATIONS
  // ============================================================================

  /// Get announcement by ID with author data
  Future<Announcement?> getAnnouncementById(String id) async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.announcementsTable,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (result.isEmpty) return null;

      final announcement = Announcement.fromJson(result.first);
      announcement.author = await getUserById(announcement.authorId);
      return announcement;
    } catch (e) {
      debugPrint('❌ Error getting announcement: $e');
      return null;
    }
  }

  /// Get all active announcements
  Future<List<Announcement>> getAllAnnouncements() async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.announcementsTable,
        where: 'is_active = 1',
        orderBy: 'created_at DESC',
      );
      return result.map((json) => Announcement.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error getting all announcements: $e');
      return [];
    }
  }

  /// Get announcements targeted to a specific user based on their role
  Future<List<Announcement>> getAnnouncementsForUser(User user) async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.announcementsTable,
        where: 'is_active = 1',
        orderBy: 'created_at DESC',
      );

      final announcements = result
          .map((json) => Announcement.fromJson(json))
          .toList();

      return announcements
          .where((announcement) => announcement.isTargetedToUser(user))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting announcements for user: $e');
      return [];
    }
  }

  /// Insert new announcement
  Future<String> insertAnnouncement(Announcement announcement) async {
    try {
      final db = await database;
      announcement.updateTimestamp();

      await db.insert(
        DatabaseConstants.announcementsTable,
        announcement.toJson(),
      );
      await _addSyncMetadata(
        DatabaseConstants.announcementsTable,
        announcement.id,
        SyncAction.create,
        announcement.toJson(),
      );

      debugPrint('✅ Announcement created: ${announcement.title}');
      return announcement.id;
    } catch (e) {
      debugPrint('❌ Error inserting announcement: $e');
      rethrow;
    }
  }

  /// Update existing announcement
  Future<void> updateAnnouncement(Announcement announcement) async {
    try {
      final db = await database;
      announcement.updateTimestamp();

      await db.update(
        DatabaseConstants.announcementsTable,
        announcement.toJson(),
        where: 'id = ?',
        whereArgs: [announcement.id],
      );
      await _addSyncMetadata(
        DatabaseConstants.announcementsTable,
        announcement.id,
        SyncAction.update,
        announcement.toJson(),
      );

      debugPrint('✅ Announcement updated: ${announcement.title}');
    } catch (e) {
      debugPrint('❌ Error updating announcement: $e');
      rethrow;
    }
  }

  /// Soft delete announcement (set is_active = 0)
  Future<void> deleteAnnouncement(String id) async {
    try {
      final db = await database;
      await db.update(
        DatabaseConstants.announcementsTable,
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _addSyncMetadata(
        DatabaseConstants.announcementsTable,
        id,
        SyncAction.update,
        {'is_active': 0},
      );

      debugPrint('✅ Announcement deactivated: $id');
    } catch (e) {
      debugPrint('❌ Error deleting announcement: $e');
      rethrow;
    }
  }

  // ============================================================================
  // CHAT OPERATIONS
  // ============================================================================

  /// Initialize chat tables (called during database initialization)
  Future<void> _initializeChatTables(Database db) async {
    try {
      // Create chat_rooms table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_rooms (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          participant_ids TEXT NOT NULL,
          last_message_id TEXT,
          last_activity TEXT,
          is_active INTEGER DEFAULT 1,
          created_at TEXT,
          updated_at TEXT,
          last_sync TEXT
        )
      ''');

      // Create messages table
      await db.execute('''
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
          created_at TEXT,
          updated_at TEXT,
          last_sync TEXT,
          FOREIGN KEY (sender_id) REFERENCES users (id),
          FOREIGN KEY (receiver_id) REFERENCES users (id),
          FOREIGN KEY (chat_room_id) REFERENCES chat_rooms (id)
        )
      ''');

      // Create indexes for better performance
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_messages_chat_room ON messages (chat_room_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages (sender_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages (receiver_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_chat_rooms_participants ON chat_rooms (participant_ids)',
      );

      debugPrint('✅ Chat tables initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing chat tables: $e');
      rethrow;
    }
  }

  // ============================================================================
  // SYNC OPERATIONS
  // ============================================================================

  /// Add sync metadata for tracking changes
  Future<void> _addSyncMetadata(
    String tableName,
    String recordId,
    SyncAction action,
    Map<String, dynamic> data,
  ) async {
    try {
      final db = await database;
      final syncMetadata = SyncMetadata(
        tableName: tableName,
        recordId: recordId,
        action: action,
        data: data,
      );

      await db.insert(
        DatabaseConstants.syncMetadataTable,
        syncMetadata.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Error adding sync metadata: $e');
      // Don't rethrow as sync metadata is not critical
    }
  }

  /// Get pending sync items
  Future<List<SyncMetadata>> getPendingSyncItems() async {
    try {
      final db = await database;
      final result = await db.query(
        DatabaseConstants.syncMetadataTable,
        where: 'is_synced = 0',
        orderBy: 'created_at ASC',
      );
      return result.map((json) => SyncMetadata.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error getting pending sync items: $e');
      return [];
    }
  }

  /// Mark sync item as complete
  Future<void> markSyncComplete(String syncId) async {
    try {
      final db = await database;
      await db.update(
        DatabaseConstants.syncMetadataTable,
        {'is_synced': 1, 'synced_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [syncId],
      );

      debugPrint('✅ Sync item marked complete: $syncId');
    } catch (e) {
      debugPrint('❌ Error marking sync complete: $e');
    }
  }

  // ============================================================================
  // DATABASE UTILITY OPERATIONS
  // ============================================================================

  /// Check if database has data
  Future<bool> hasData() async {
    try {
      final db = await database;

      final userCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM users',
      );
      final courseCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM courses',
      );
      final announcementCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM announcements',
      );

      final users = userCount.first['count'] as int;
      final courses = courseCount.first['count'] as int;
      final announcements = announcementCount.first['count'] as int;

      debugPrint(
        '📊 Database contents: $users users, $courses courses, $announcements announcements',
      );

      return users > 0 || courses > 0 || announcements > 0;
    } catch (e) {
      debugPrint('❌ Error checking database data: $e');
      return false;
    }
  }

  /// Debug method to show database contents (for development)
  Future<void> debugDatabaseContents() async {
    if (!kDebugMode) return; // Only run in debug mode

    try {
      final db = await database;

      debugPrint('🔍 === DATABASE DEBUG INFO ===');

      // Users with roles
      final users = await db.rawQuery('''
        SELECT u.username, u.first_name, u.last_name, r.name as role_name, u.is_active
        FROM users u
        LEFT JOIN roles r ON u.role_id = r.id
        ORDER BY r.name, u.username
      ''');
      debugPrint('👥 Users (${users.length}):');
      for (final user in users) {
        final active = user['is_active'] == 1 ? '✅' : '❌';
        debugPrint(
          '  $active ${user['username']} (${user['first_name']} ${user['last_name']}) - ${user['role_name']}',
        );
      }

      // Courses with lecturers
      final courses = await db.rawQuery('''
        SELECT c.code, c.name, u.first_name || ' ' || u.last_name as lecturer_name, c.is_active
        FROM courses c
        LEFT JOIN users u ON c.lecturer_id = u.id
        ORDER BY c.code
      ''');
      debugPrint('📚 Courses (${courses.length}):');
      for (final course in courses) {
        final active = course['is_active'] == 1 ? '✅' : '❌';
        debugPrint(
          '  $active ${course['code']} - ${course['name']} (${course['lecturer_name'] ?? 'No lecturer'})',
        );
      }

      // Enrollments
      final enrollments = await db.rawQuery('''
        SELECT u.username as student, c.code as course, e.status
        FROM enrollments e
        JOIN users u ON e.student_id = u.id
        JOIN courses c ON e.course_id = c.id
        ORDER BY u.username, c.code
      ''');
      debugPrint('📝 Enrollments (${enrollments.length}):');
      for (final enrollment in enrollments) {
        final status = enrollment['status'] == 'active' ? '✅' : '❌';
        debugPrint(
          '  $status ${enrollment['student']} -> ${enrollment['course']}',
        );
      }

      // Announcements
      final announcements = await db.query(
        'announcements',
        columns: ['title', 'is_active'],
      );
      debugPrint('📢 Announcements (${announcements.length}):');
      for (final announcement in announcements) {
        final active = announcement['is_active'] == 1 ? '✅' : '❌';
        debugPrint('  $active ${announcement['title']}');
      }

      debugPrint('🔍 === END DEBUG INFO ===');
    } catch (e) {
      debugPrint('❌ Error in debugDatabaseContents: $e');
    }
  }
  /// Close database connection
  Future<void> close() async {
    try {
      final db = _database;
      if (db != null) {
        await db.close();
        _database = null;
        debugPrint('✅ Database connection closed');
      }
    } catch (e) {
      debugPrint('❌ Error closing database: $e');
    }
  }
    Future<List<User>> getAllLecturers() async {
    try {
      final response = await http.get(Uri.parse('http://192.168.1.155:5000/api/lecturers'));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        final List<dynamic> items = body is List ? body : (body['items'] ?? []);

        return items.map((json) => User.fromJson(json)).toList();
      } else {
        throw Exception("Failed to fetch lecturers: ${response.body}");
      }
    } catch (e) {
      throw Exception("Error fetching lecturers: $e");
    }
  }
    Future<void> enrollUserInCourse(String studentId, String courseId) async {
    final response = await http.post(
      Uri.parse('192.168.1.155:5000/enrollments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'student_id': studentId,
        'course_id': courseId,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to enroll: ${response.body}');
    }
  }
}

