# 四、构建系统

### 8. build_manifest

```sql
build_manifest (
    id bigint PK,
    software_manifest_id bigint FK -> software_manifest.id,
    status enum(pending, running, success, failed, cancelled),
    build_output_file_id bigint FK -> file.id,
    build_log text,
    build_config text,
    started_at timestamptz,
    finished_at timestamptz,
    created_at timestamptz,
    created_by bigint FK -> user.id
)
```

### 9. release

```sql
release (
    id bigint PK,
    build_manifest_id bigint FK -> build_manifest.id,
    name varchar,
    channel enum(dev, qa, beta, prod),
    platform enum(web, android, ios, desktop),
    status enum(active, rolled_back, archived),
    version_tag varchar,
    release_notes text,
    preview_url varchar,
    download_url varchar,
    created_at timestamptz,
    published_at timestamptz,
    created_by bigint FK -> user.id
)
```
