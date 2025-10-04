# VelocityVer Academic Report - Flowcharts and Diagrams

## Figure 3.1: System Architecture Diagram

```mermaid
graph TB
    subgraph "Client Layer (Mobile Devices)"
        A[Flutter Mobile App]
        B[Local SQLite Database]
        C[Cache Manager]
        D[Sync Engine]
        E[UI Components]
    end
    
    subgraph "Network Layer"
        F[Wi-Fi Network]
        G[Auto Discovery Protocol]
    end
    
    subgraph "Server Layer (Local Server)"
        H[Python Flask Server]
        I[Authentication Module]
        J[File Manager]
        K[API Endpoints]
        L[Sync Coordinator]
    end
    
    subgraph "Data Layer"
        M[SQLite Database]
        N[File Storage]
        O[Backup System]
    end
    
    A --> B
    A --> C
    A --> D
    A --> E
    
    A <--> F
    F <--> G
    F <--> H
    
    H --> I
    H --> J
    H --> K
    H --> L
    
    H <--> M
    H <--> N
    H <--> O
    
    D <--> L
    C <--> J
```

## Figure 3.2: Use Case Diagram

```mermaid
graph LR
    subgraph "Actors"
        S[Student]
        L[Lecturer]
        A[Administrator]
        SA[Super Admin]
    end
    
    subgraph "VelocityVer System"
        UC1[Login/Authenticate]
        UC2[Browse Resources]
        UC3[Download Files]
        UC4[Upload Files]
        UC5[Manage Courses]
        UC6[Submit Assignments]
        UC7[Manage Users]
        UC8[System Configuration]
        UC9[View Analytics]
        UC10[Sync Data]
        UC11[Manage Permissions]
        UC12[Generate Reports]
    end
    
    S --> UC1
    S --> UC2
    S --> UC3
    S --> UC6
    S --> UC10
    
    L --> UC1
    L --> UC2
    L --> UC3
    L --> UC4
    L --> UC5
    L --> UC9
    L --> UC10
    
    A --> UC1
    A --> UC2
    A --> UC3
    A --> UC4
    A --> UC5
    A --> UC7
    A --> UC9
    A --> UC10
    A --> UC11
    A --> UC12
    
    SA --> UC1
    SA --> UC2
    SA --> UC3
    SA --> UC4
    SA --> UC5
    SA --> UC7
    SA --> UC8
    SA --> UC9
    SA --> UC10
    SA --> UC11
    SA --> UC12
```

## Figure 3.3: Database Entity Relationship Diagram

```mermaid
erDiagram
    USERS {
        int user_id PK
        string username
        string email
        string password_hash
        string first_name
        string last_name
        string profile_picture
        datetime created_at
        datetime updated_at
    }
    
    ROLES {
        int role_id PK
        string role_name
        string description
        int permission_level
    }
    
    USER_ROLES {
        int user_role_id PK
        int user_id FK
        int role_id FK
        datetime assigned_at
    }
    
    FACULTIES {
        int faculty_id PK
        string faculty_name
        string description
        datetime created_at
    }
    
    DEPARTMENTS {
        int department_id PK
        string department_name
        string description
        int faculty_id FK
        datetime created_at
    }
    
    COURSES {
        int course_id PK
        string course_code
        string course_title
        string description
        int department_id FK
        int academic_level_id FK
        int credit_hours
        datetime created_at
    }
    
    FILES {
        int file_id PK
        string original_filename
        string storage_path
        int file_size
        string mime_type
        int course_id FK
        int uploaded_by FK
        datetime uploaded_at
        datetime updated_at
    }
    
    SYNC_METADATA {
        int sync_id PK
        string entity_type
        int entity_id
        datetime last_modified
        string sync_status
        string conflict_data
    }
    
    USERS ||--o{ USER_ROLES : has
    ROLES ||--o{ USER_ROLES : assigned_to
    FACULTIES ||--o{ DEPARTMENTS : contains
    DEPARTMENTS ||--o{ COURSES : offers
    COURSES ||--o{ FILES : contains
    USERS ||--o{ FILES : uploads
```

## Figure 4.7: Server Discovery Process Flow

```mermaid
sequenceDiagram
    participant C as Client App
    participant N as Network
    participant S as Server
    
    Note over C,S: Automatic Server Discovery Process
    
    C->>N: Broadcast discovery request
    Note right of C: UDP broadcast on port 8888
    
    S->>N: Listen for discovery requests
    Note left of S: Server monitoring broadcasts
    
    N->>S: Forward discovery request
    
    S->>N: Send server announcement
    Note left of S: Include server info, capabilities
    
    N->>C: Forward server response
    
    C->>C: Evaluate server response
    Note right of C: Check compatibility, response time
    
    C->>S: Send connection request
    Note over C,S: HTTP connection establishment
    
    S->>C: Send connection confirmation
    Note left of S: Include authentication requirements
    
    C->>S: Send authentication credentials
    
    S->>C: Authentication response
    Note left of S: Success/failure with token
    
    alt Authentication Success
        C->>S: Request initial data sync
        S->>C: Send user-specific data
        Note over C,S: Offline-first cache population
    else Authentication Failure
        S->>C: Error response
        C->>C: Retry or manual configuration
    end
```

## Figure 4.8: System Performance Metrics

```mermaid
graph TB
    subgraph "Performance Dashboard"
        A[Response Time: 1.2s avg]
        B[Concurrent Users: 500 max]
        C[Offline Duration: 30 days]
        D[Sync Success: 98.5%]
        E[Data Integrity: 99.9%]
        F[Cache Hit Rate: 85%]
        G[Storage Efficiency: 78%]
        H[Battery Usage: Low]
    end
    
    subgraph "Load Testing Results"
        I[Light Load: <100 users]
        J[Medium Load: 100-300 users]
        K[Heavy Load: 300-500 users]
        L[Stress Test: >500 users]
    end
    
    subgraph "Response Times"
        M[Login: 0.8s]
        N[File Download: 2.1s]
        O[File Upload: 3.4s]
        P[Sync Operation: 5.2s]
    end
    
    A --> I
    B --> J
    C --> K
    D --> L
    
    I --> M
    J --> N
    K --> O
    L --> P
```
