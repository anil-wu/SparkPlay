# 二、文件系统

### 4. files

```sql
CREATE TABLE IF NOT EXISTS `files` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NOT NULL,
  `file_category` ENUM('text','image','video','audio','binary','archive') NOT NULL,
  `file_format` VARCHAR(50) NOT NULL COMMENT '文件格式，如 png, jpg, mp4, mp3, txt 等',
  `current_version_id` BIGINT UNSIGNED DEFAULT NULL COMMENT '当前版本ID，关联 file_versions.id',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_files_current_version_id` (`current_version_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 5. project_files

项目与文件的关联表，支持一个文件属于多个项目。

```sql
CREATE TABLE IF NOT EXISTS `project_files` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `project_id` BIGINT UNSIGNED NOT NULL,
  `file_id` BIGINT UNSIGNED NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_project_file` (`project_id`,`file_id`),
  KEY `idx_project_files_file_id` (`file_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 6. file_versions

```sql
CREATE TABLE IF NOT EXISTS `file_versions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `file_id` BIGINT UNSIGNED NOT NULL,
  `version_number` BIGINT UNSIGNED NOT NULL,
  `size_bytes` BIGINT UNSIGNED NOT NULL,
  `hash` VARCHAR(128) NOT NULL,
  `storage_key` VARCHAR(512) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_by` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_file_version` (`file_id`,`version_number`),
  KEY `idx_file_versions_file_id` (`file_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

