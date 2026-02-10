# 六、Agent 与模型映射

### 15. agents

```sql
CREATE TABLE IF NOT EXISTS `agents` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(128) NOT NULL,
  `description` TEXT,
  `agent_type` ENUM('code','asset','design','test','build','ops') NOT NULL DEFAULT 'code',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_agents_name_type` (`name`,`agent_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 16. agent_llm_bindings

```sql
CREATE TABLE IF NOT EXISTS `agent_llm_bindings` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `agent_id` BIGINT UNSIGNED NOT NULL,
  `llm_model_id` BIGINT UNSIGNED NOT NULL,
  `priority` INT NOT NULL DEFAULT 0,
  `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_agent_llm_bindings_agent_id` (`agent_id`),
  KEY `idx_agent_llm_bindings_model_id` (`llm_model_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

