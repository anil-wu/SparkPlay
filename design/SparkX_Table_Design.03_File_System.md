# 二、文件系统

### 4. file

```sql
file (
    id bigint PK,
    project_id bigint FK -> project.id,
    name varchar,
    file_category enum(text, image, video, audio, binary),
    file_format varchar,
    current_version_id bigint FK -> file_version.id,
    created_at timestamptz
)
```

### 5. file_version

```sql
file_version (
    id bigint PK,
    file_id bigint FK -> file.id,
    version_number int,
    size_bytes bigint,
    hash varchar,
    storage_key varchar,
    mime_type varchar,
    created_at timestamptz,
    created_by bigint FK -> user.id
)
```

