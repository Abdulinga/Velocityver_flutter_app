class DatabaseConstants {
  static const String databaseName = 'velocityver.db';
  static const int databaseVersion = 4;

  // Table names
  static const String usersTable = 'users';
  static const String rolesTable = 'roles';
  static const String facultiesTable = 'faculties';
  static const String departmentsTable = 'departments';
  static const String levelsTable = 'levels';
  static const String yearsTable = 'years';
  static const String coursesTable = 'courses';
  static const String filesTable = 'files';
  static const String announcementsTable = 'announcements';
  static const String syncMetadataTable = 'sync_metadata';
  static const String userCoursesTable = 'user_courses';

  // Users table
  static const String usersCreateTable =
      '''
    CREATE TABLE $usersTable (
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
      FOREIGN KEY (role_id) REFERENCES $rolesTable (id),
      FOREIGN KEY (level_id) REFERENCES $levelsTable (id),
      FOREIGN KEY (year_id) REFERENCES $yearsTable (id),
      FOREIGN KEY (department_id) REFERENCES $departmentsTable (id),
      FOREIGN KEY (faculty_id) REFERENCES $facultiesTable (id)
    )
  ''';

  // Roles table
  static const String rolesCreateTable =
      '''
    CREATE TABLE $rolesTable (
      id TEXT PRIMARY KEY,
      name TEXT UNIQUE NOT NULL,
      description TEXT,
      permissions TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_sync TEXT
    )
  ''';

  // Faculties table
  static const String facultiesCreateTable =
      '''
    CREATE TABLE $facultiesTable (
      id TEXT PRIMARY KEY,
      name TEXT UNIQUE NOT NULL,
      code TEXT UNIQUE NOT NULL,
      description TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_sync TEXT,
      deanId TEXT,
      isActive INTEGER NOT NULL DEFAULT 1
    )
  ''';

  // Departments table
  static const String departmentsCreateTable =
      '''
    CREATE TABLE $departmentsTable (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      code TEXT UNIQUE NOT NULL,
      faculty_id TEXT NOT NULL,
      description TEXT,
      hodId TEXT,
      isActive INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_sync TEXT,
      FOREIGN KEY (faculty_id) REFERENCES $facultiesTable (id)
    )
  ''';

  // Levels table
  static const String levelsCreateTable =
      '''
    CREATE TABLE $levelsTable (
      id TEXT PRIMARY KEY,
      name TEXT UNIQUE NOT NULL,
      code TEXT UNIQUE NOT NULL,
      description TEXT,
      order_num INTEGER NOT NULL,
      isActive INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_sync TEXT
    )
  ''';

  // Years table
  static const String yearsCreateTable =
      '''
    CREATE TABLE $yearsTable (
      id TEXT PRIMARY KEY,
      name TEXT UNIQUE NOT NULL,
      code TEXT UNIQUE NOT NULL,
      description TEXT,
      order_num INTEGER NOT NULL,
      isActive INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_sync TEXT
    )
  ''';

  // Courses table
  static const String coursesCreateTable =
      '''
    CREATE TABLE $coursesTable (
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
      FOREIGN KEY (level_id) REFERENCES $levelsTable (id),
      FOREIGN KEY (year_id) REFERENCES $yearsTable (id),
      FOREIGN KEY (department_id) REFERENCES $departmentsTable (id),
      FOREIGN KEY (faculty_id) REFERENCES $facultiesTable (id),
      FOREIGN KEY (lecturer_id) REFERENCES $usersTable (id)
    )
  ''';

  // Files table
  static const String filesCreateTable =
      '''
    CREATE TABLE $filesTable (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      original_name TEXT NOT NULL,
      file_path TEXT NOT NULL,
      file_size INTEGER NOT NULL,
      mime_type TEXT NOT NULL,
      course_id TEXT NOT NULL,
      uploaded_by TEXT NOT NULL,
      description TEXT,
      is_synced INTEGER DEFAULT 0,
      local_path TEXT,
      server_path TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_sync TEXT,
      FOREIGN KEY (course_id) REFERENCES $coursesTable (id),
      FOREIGN KEY (uploaded_by) REFERENCES $usersTable (id)
    )
  ''';

  // Announcements table
  static const String announcementsCreateTable =
      '''
    CREATE TABLE $announcementsTable (
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
      FOREIGN KEY (author_id) REFERENCES $usersTable (id)
    )
  ''';

  // User courses junction table
  static const String userCoursesCreateTable =
      '''
    CREATE TABLE $userCoursesTable (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      course_id TEXT NOT NULL,
      enrolled_at TEXT NOT NULL,
      last_sync TEXT,
      FOREIGN KEY (user_id) REFERENCES $usersTable (id),
      FOREIGN KEY (course_id) REFERENCES $coursesTable (id),
      UNIQUE(user_id, course_id)
    )
  ''';

  // Sync metadata table
  static const String syncMetadataCreateTable =
      '''
    CREATE TABLE $syncMetadataTable (
      id TEXT PRIMARY KEY,
      table_name TEXT NOT NULL,
      record_id TEXT NOT NULL,
      action TEXT NOT NULL,
      data TEXT,
      created_at TEXT NOT NULL,
      synced_at TEXT,
      is_synced INTEGER DEFAULT 0,
      UNIQUE(table_name, record_id, action)
    )
  ''';

  // Indexes for better performance
  static const List<String> indexes = [
    'CREATE INDEX idx_users_username ON $usersTable (username)',
    'CREATE INDEX idx_users_email ON $usersTable (email)',
    'CREATE INDEX idx_users_role ON $usersTable (role_id)',
    'CREATE INDEX idx_courses_code ON $coursesTable (code)',
    'CREATE INDEX idx_courses_lecturer ON $coursesTable (lecturer_id)',
    'CREATE INDEX idx_files_course ON $filesTable (course_id)',
    'CREATE INDEX idx_files_uploader ON $filesTable (uploaded_by)',
    'CREATE INDEX idx_announcements_author ON $announcementsTable (author_id)',
    'CREATE INDEX idx_user_courses_user ON $userCoursesTable (user_id)',
    'CREATE INDEX idx_user_courses_course ON $userCoursesTable (course_id)',
    'CREATE INDEX idx_sync_metadata_table ON $syncMetadataTable (table_name)',
    'CREATE INDEX idx_sync_metadata_synced ON $syncMetadataTable (is_synced)',
  ];

  // Default roles
  static const List<Map<String, dynamic>> defaultRoles = [
    {
      'id': 'role_student',
      'name': 'Student',
      'description': 'Student role with access to course materials',
      'permissions': '["view_courses", "download_files", "view_announcements"]',
    },
    {
      'id': 'role_lecturer',
      'name': 'Lecturer',
      'description': 'Lecturer role with course management capabilities',
      'permissions':
          '["view_courses", "manage_course_files", "view_announcements", "upload_files"]',
    },
    {
      'id': 'role_admin',
      'name': 'Admin',
      'description': 'Administrator role with user and system management',
      'permissions':
          '["manage_users", "manage_courses", "manage_announcements", "view_all_files", "manage_system"]',
    },
    {
      'id': 'role_super_admin',
      'name': 'Super Admin',
      'description': 'Super administrator with full system access',
      'permissions': '["full_access"]',
    },
  ];

  // Default super admin user
  static const Map<String, dynamic> defaultSuperAdmin = {
    'id': 'user_super_admin',
    'username': 'superadmin',
    'email': 'superadmin@velocityver.com',
    'password_hash': 'hashed_password_here', // Will be properly hashed
    'role_id': 'role_super_admin',
    'first_name': 'Super',
    'last_name': 'Admin',
    'is_active': 1,
  };
}
