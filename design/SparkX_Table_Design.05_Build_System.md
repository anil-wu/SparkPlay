# 四、构建系统

### 10. build_version

```sql
build_version (
    id bigint PK,
    project_id bigint FK -> project.id,
    software_manifest_id bigint FK -> software_manifest.id,
    version_number int,                  -- 构建版本号，同一软件工程下递增
    description text,
    build_version_file_id bigint FK -> file.id,
    build_version_file_version_id bigint FK -> file_version.id,
    created_at timestamptz,
    created_by bigint FK -> user.id
)
```

**索引：**
- `idx_build_versions_project_id` (project_id)
- `idx_build_versions_software_manifest_id` (software_manifest_id)
- `idx_build_versions_version_number` (version_number)
- `idx_build_versions_created_at` (created_at)

### 11. release

```sql
release (
    id bigint PK,
    project_id bigint FK -> project.id,
    build_version_id bigint FK -> build_version.id,
    release_manifest_file_id bigint FK -> file.id,
    release_manifest_file_version_id bigint FK -> file_version.id,
    name varchar,
    channel enum(dev, qa, beta, prod),
    platform enum(web, android, ios, desktop),
    status enum(active, rolled_back, archived),
    version_tag varchar,
    release_notes text,
    created_at timestamptz,
    published_at timestamptz,
    created_by bigint FK -> user.id
)
```
