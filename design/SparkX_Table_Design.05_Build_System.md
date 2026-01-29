# 四、构建系统

### 8. build

```sql
build (
    id bigint PK,
    project_version_id bigint FK -> project_version.id,
    status enum(pending, running, success, failed),
    output_file_id bigint FK -> file.id,
    created_at timestamptz,
    finished_at timestamptz
)
```

### 8b. project_release

```sql
project_release (
    id bigint PK,
    project_version_id bigint FK -> project_version.id,
    build_id bigint FK -> build.id,
    channel enum(dev, qa, beta, prod),
    platform enum(web, android, ios),
    status enum(pending, published, rolled_back),
    version_tag varchar,
    release_notes text,
    preview_url varchar,
    download_url varchar,
    created_at timestamptz,
    published_at timestamptz,
    created_by bigint FK -> user.id
)
```
