# 三、软件工程 & Manifest

### 6. software

```sql
software (
    id bigint PK,
    project_id bigint FK -> project.id,
    name varchar,
    description text,
    technology_stack varchar,
    status enum(active, archived),
    created_at timestamptz,
    updated_at timestamptz,
    current_software_manifest_id bigint FK -> software_manifest.id,
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
    template_type enum(game, web_app, library, tool),
    technology_stack varchar,
    folder_structure text,
    default_manifest_config text,
    template_file_id bigint FK -> file.id,
    status enum(active, archived),
    is_public boolean,
    usage_count int,
    created_at timestamptz,
    updated_at timestamptz,
    created_by bigint FK -> user.id
)
```

