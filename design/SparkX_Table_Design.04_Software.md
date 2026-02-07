# 三、软件工程 & Manifest

### 6. software

```sql
software (
    id bigint PK,
    project_id bigint FK -> project.id,
    name varchar,
    description text,
    manifest_id bigint FK -> software_manifest.id,
    template_id bigint FK -> software_template.id,
    technology_stack varchar,
    status enum(active, archived),
    created_at timestamptz,
    updated_at timestamptz,
    created_by bigint FK -> user.id
)
### 7. software_manifest

```sql
software_manifest (
    id bigint PK,
    software_id bigint FK -> software.id,
    manifest_file_id bigint FK -> file.id,
    version_number int,
    description text,
    created_at timestamptz,
    created_by bigint FK -> user.id
)
```

### 8. software_template

```sql
software_template (
    id bigint PK,
    name varchar,
    description text,
    archive_file_id bigint FK -> file.id,
    created_at timestamptz,
    updated_at timestamptz,
    created_by bigint FK -> user.id
)
```

