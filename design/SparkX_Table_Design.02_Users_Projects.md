# 一、用户与项目

### 1. user

```sql
user (
    id bigint PK,
    username varchar UNIQUE,
    email varchar UNIQUE,
    password_hash varchar,
    status enum(active, disabled),
    created_at timestamptz,
    updated_at timestamptz
)
```

### 2. project

```sql
project (
    id bigint PK,
    name varchar,
    description text,
    cover_image_file_id bigint FK -> file.id,
    owner_id bigint FK -> user.id,
    status enum(active, archived),
    created_at timestamptz,
    updated_at timestamptz
)
```

### 3. project_member

```sql
project_member (
    id bigint PK,
    project_id bigint FK -> project.id,
    user_id bigint FK -> user.id,
    role enum(owner, admin, developer, viewer),
    created_at timestamptz
)
```

