# 五、LLM / AI 相关

### 12. llm_providers

```sql
CREATE TABLE IF NOT EXISTS `llm_providers` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(128) NOT NULL,
  `base_url` VARCHAR(512) NOT NULL DEFAULT '',
  `api_key` TEXT,
  `description` TEXT,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_llm_providers_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 13. llm_models

```sql
CREATE TABLE IF NOT EXISTS `llm_models` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `provider_id` BIGINT UNSIGNED NOT NULL,
  `model_name` VARCHAR(255) NOT NULL,
  `model_type` ENUM('llm','vlm','embedding') NOT NULL DEFAULT 'llm',
  `max_input_tokens` INT NOT NULL DEFAULT 0,
  `max_output_tokens` INT NOT NULL DEFAULT 0,
  `support_stream` BOOLEAN NOT NULL DEFAULT FALSE,
  `support_json` BOOLEAN NOT NULL DEFAULT FALSE,
  `price_input_per_1k` DECIMAL(10,6) NOT NULL DEFAULT 0,
  `price_output_per_1k` DECIMAL(10,6) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_llm_models_provider_model` (`provider_id`,`model_name`,`model_type`),
  KEY `idx_llm_models_provider_id` (`provider_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 14. llm_usage_logs

```sql
CREATE TABLE IF NOT EXISTS `llm_usage_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `llm_model_id` BIGINT UNSIGNED NOT NULL,
  `project_id` BIGINT UNSIGNED NOT NULL,
  `input_tokens` INT NOT NULL DEFAULT 0,
  `output_tokens` INT NOT NULL DEFAULT 0,
  `cache_hit` BOOLEAN NOT NULL DEFAULT FALSE,
  `cost_usd` DECIMAL(10,6) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_llm_usage_logs_model_id` (`llm_model_id`),
  KEY `idx_llm_usage_logs_project_id` (`project_id`),
  KEY `idx_llm_usage_logs_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

