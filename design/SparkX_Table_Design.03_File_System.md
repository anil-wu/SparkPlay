# 二、文件系统

### 4. file

```sql
file (
    id bigint PK,
    name varchar,
    file_category enum(text, image, video, audio, binary),
    file_format varchar,
    current_version_id bigint FK -> file_version.id,
    created_at timestamptz
)
```

### 5. project_file

项目与文件的关联表，支持一个文件属于多个项目。

```sql
project_file (
    id bigint PK,
    project_id bigint FK -> project.id,
    file_id bigint FK -> file.id,
    created_at timestamptz
)
```

### 6. file_version

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

