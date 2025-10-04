# VelocityVer Academic Report - Tables

## Table 4.1: Technology Stack and System Requirements

| Component | Technology | Version | Justification |
|-----------|------------|---------|---------------|
| **Mobile Framework** | Flutter | 3.16.0 | Android development, excellent offline capabilities, native performance |
| **Programming Language (Client)** | Dart | 3.1.0 | Optimized for Flutter, strong typing, excellent performance |
| **Server Framework** | Python Flask | 2.3.0 | Lightweight, easy deployment, extensive documentation |
| **Programming Language (Server)** | Python | 3.11.0 | Rapid development, extensive libraries, educational institution familiarity |
| **Database Engine** | SQLite | 3.42.0 | Serverless, zero-configuration, excellent for offline-first architecture |
| **Development IDE (Mobile)** | Android Studio | 2023.1.1 | Comprehensive debugging, device emulation, integrated version control |
| **Development IDE (Server)** | PyCharm Professional | 2023.2 | Advanced Python debugging, database integration, project management |
| **Database Management** | DB Browser for SQLite | 3.12.2 | Visual database design, query development, data inspection |
| **Version Control** | Git | 2.41.0 | Distributed version control, collaboration support |
| **Repository Hosting** | GitHub | - | Remote repository, issue tracking, collaboration features |
| **API Testing** | Postman | 10.18.0 | API endpoint testing, request/response validation |
| **UI/UX Design** | Figma | - | Interface design, prototyping, design collaboration |

**System Requirements:**
- **Target Platform:** Android 6.0 (API level 23) and above
- **Server OS:** Windows 10/11, Ubuntu 20.04+, macOS 12+
- **RAM Requirements:** 4GB minimum, 8GB recommended
- **Storage:** 2GB available space for application and cache
- **Network:** Wi-Fi capability (internet not required for operation)

---

## Table 4.2: Database Schema Overview

| Table Name | Primary Key | Foreign Keys | Purpose | Testing Coverage |
|------------|-------------|--------------|---------|------------------|
| **users** | user_id | role_id | Store user account information | 100% |
| **roles** | role_id | - | Define user role types and permissions | 100% |
| **user_roles** | user_role_id | user_id, role_id | Map users to roles (many-to-many) | 100% |
| **faculties** | faculty_id | - | Academic faculty information | 95% |
| **departments** | department_id | faculty_id | Department details within faculties | 95% |
| **courses** | course_id | department_id | Course information and metadata | 98% |
| **academic_levels** | level_id | - | Academic levels (100L, 200L, etc.) | 90% |
| **academic_years** | year_id | - | Academic year definitions | 90% |
| **files** | file_id | course_id, uploaded_by | File metadata and storage paths | 100% |
| **file_categories** | category_id | parent_category_id | Hierarchical file categorization | 85% |
| **file_permissions** | permission_id | file_id, role_id | File access permissions | 100% |
| **sync_metadata** | sync_id | - | Synchronization tracking | 95% |
| **device_cache** | cache_id | user_id, file_id | Local cache management | 90% |
| **activity_logs** | log_id | user_id | System activity audit trail | 100% |
| **error_logs** | error_id | user_id | Error tracking and debugging | 85% |

**Key Relationships:**
- Users can have multiple roles through user_roles junction table
- Files belong to courses, which belong to departments, which belong to faculties
- File permissions are role-based, allowing granular access control
- Sync metadata tracks all changes for conflict resolution

---

## Table 4.3: API Endpoints and Functionalities

| Endpoint | Method | Purpose | Authentication Required | Testing Status |
|----------|--------|---------|------------------------|----------------|
| `/api/auth/login` | POST | User authentication | No | ✅ Passed |
| `/api/auth/logout` | POST | User logout | Yes | ✅ Passed |
| `/api/auth/refresh` | POST | Token refresh | Yes | ✅ Passed |
| `/api/users` | GET | List users (admin only) | Yes | ✅ Passed |
| `/api/users` | POST | Create new user | Yes | ✅ Passed |
| `/api/users/{id}` | PUT | Update user information | Yes | ✅ Passed |
| `/api/users/{id}` | DELETE | Delete user account | Yes | ✅ Passed |
| `/api/courses` | GET | List available courses | Yes | ✅ Passed |
| `/api/courses` | POST | Create new course | Yes | ✅ Passed |
| `/api/courses/{id}/files` | GET | List course files | Yes | ✅ Passed |
| `/api/files/upload` | POST | Upload new file | Yes | ✅ Passed |
| `/api/files/{id}/download` | GET | Download file | Yes | ✅ Passed |
| `/api/files/{id}` | DELETE | Delete file | Yes | ✅ Passed |
| `/api/sync/status` | GET | Get synchronization status | Yes | ✅ Passed |
| `/api/sync/pull` | POST | Pull server changes | Yes | ✅ Passed |
| `/api/sync/push` | POST | Push local changes | Yes | ✅ Passed |
| `/api/discovery/announce` | GET | Server discovery broadcast | No | ✅ Passed |
| `/api/system/health` | GET | System health check | No | ✅ Passed |
| `/api/analytics/usage` | GET | Usage statistics | Yes | ✅ Passed |
| `/api/admin/logs` | GET | System logs (admin only) | Yes | ✅ Passed |

**Response Codes:**
- 200: Success
- 201: Created successfully
- 400: Bad request
- 401: Unauthorized
- 403: Forbidden
- 404: Not found
- 500: Internal server error

---

## Table 4.4: User Role Permissions Matrix

| Permission | Student | Lecturer | Administrator | Super Admin |
|------------|---------|----------|---------------|-------------|
| **Authentication & Profile** |
| Login to system | ✅ | ✅ | ✅ | ✅ |
| Update own profile | ✅ | ✅ | ✅ | ✅ |
| Change own password | ✅ | ✅ | ✅ | ✅ |
| **File Operations** |
| View course files | ✅ | ✅ | ✅ | ✅ |
| Download files | ✅ | ✅ | ✅ | ✅ |
| Upload files | ❌ | ✅ | ✅ | ✅ |
| Delete own files | ❌ | ✅ | ✅ | ✅ |
| Delete any files | ❌ | ❌ | ✅ | ✅ |
| **Course Management** |
| View enrolled courses | ✅ | ✅ | ✅ | ✅ |
| View all courses | ❌ | ✅ | ✅ | ✅ |
| Create courses | ❌ | ❌ | ✅ | ✅ |
| Modify courses | ❌ | ✅* | ✅ | ✅ |
| Delete courses | ❌ | ❌ | ✅ | ✅ |
| **User Management** |
| View own information | ✅ | ✅ | ✅ | ✅ |
| View other users | ❌ | ❌ | ✅ | ✅ |
| Create user accounts | ❌ | ❌ | ✅ | ✅ |
| Modify user accounts | ❌ | ❌ | ✅ | ✅ |
| Delete user accounts | ❌ | ❌ | ✅ | ✅ |
| **System Administration** |
| View system logs | ❌ | ❌ | ✅ | ✅ |
| System configuration | ❌ | ❌ | ❌ | ✅ |
| Database management | ❌ | ❌ | ❌ | ✅ |
| Security settings | ❌ | ❌ | ❌ | ✅ |
| **Analytics & Reporting** |
| View own activity | ✅ | ✅ | ✅ | ✅ |
| View course analytics | ❌ | ✅* | ✅ | ✅ |
| View system analytics | ❌ | ❌ | ✅ | ✅ |
| Generate reports | ❌ | ❌ | ✅ | ✅ |

**Legend:**
- ✅ = Full access
- ❌ = No access
- ✅* = Limited access (only for assigned courses)

---

## Table 4.5: Testing Results Summary

| Test Category | Total Tests | Passed | Failed | Pass Rate | Coverage |
|---------------|-------------|--------|--------|-----------|----------|
| **Unit Tests** |
| Mobile App Components | 156 | 147 | 9 | 94.2% | 94% |
| Server API Endpoints | 89 | 85 | 4 | 95.5% | 96% |
| Database Operations | 67 | 64 | 3 | 95.5% | 92% |
| **Integration Tests** |
| Client-Server Communication | 45 | 42 | 3 | 93.3% | 90% |
| Database Integration | 34 | 32 | 2 | 94.1% | 88% |
| File Management | 28 | 26 | 2 | 92.9% | 85% |
| **System Tests** |
| Offline Functionality | 23 | 21 | 2 | 91.3% | - |
| Synchronization | 19 | 17 | 2 | 89.5% | - |
| Security & Authentication | 31 | 29 | 2 | 93.5% | - |
| **User Acceptance Tests** |
| Student Interface | 15 | 14 | 1 | 93.3% | - |
| Lecturer Interface | 18 | 17 | 1 | 94.4% | - |
| Administrator Interface | 12 | 11 | 1 | 91.7% | - |
| **Performance Tests** |
| Load Testing | 8 | 7 | 1 | 87.5% | - |
| Stress Testing | 6 | 5 | 1 | 83.3% | - |
| Offline Performance | 10 | 9 | 1 | 90.0% | - |

**Overall Summary:**
- **Total Tests:** 561
- **Total Passed:** 526
- **Total Failed:** 35
- **Overall Pass Rate:** 93.8%
- **Average Code Coverage:** 91.2%

**Key Performance Metrics:**
- Average Response Time: 1.2 seconds
- Maximum Concurrent Users: 500
- Offline Operation Duration: 30 days
- Synchronization Success Rate: 98.5%
- Data Integrity: 99.9%
