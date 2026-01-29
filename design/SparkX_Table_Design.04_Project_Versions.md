# 三、工程 & 工程版本

### 6. project_engine

```sql
project_engine (
    id bigint PK,
    project_id bigint FK -> project.id,
    engine enum(phaser),
    engine_version varchar,
    created_at timestamptz
)
```

### 7. project_version

```sql
project_version (
    id bigint PK,
    project_id bigint FK -> project.id,
    version_name varchar,
    version_number int,
    description text,
    root_manifest_file_id bigint FK -> file.id,
    status enum(draft, released, archived),
    created_at timestamptz,
    created_by bigint FK -> user.id
)
```

