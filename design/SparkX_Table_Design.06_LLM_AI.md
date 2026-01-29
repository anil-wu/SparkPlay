# 五、LLM / AI 相关

### 9. llm_provider

```sql
llm_provider (
    id bigint PK,
    name varchar,
    base_url varchar,
    api_key text,
    description text,
    created_at timestamptz
)
```

### 10. llm_model

```sql
llm_model (
    id bigint PK,
    provider_id bigint FK -> llm_provider.id,
    model_name varchar,
    model_type enum(llm, vlm, embedding),
    max_input_tokens int,
    max_output_tokens int,
    support_stream boolean,
    support_json boolean,
    price_input_per_1k numeric(10,6),
    price_output_per_1k numeric(10,6),
    created_at timestamptz
)
```

### 11. llm_usage_log

```sql
llm_usage_log (
    id bigint PK,
    llm_model_id bigint FK -> llm_model.id,
    project_id bigint FK -> project.id,
    input_tokens int,
    output_tokens int,
    cache_hit boolean,
    cost_usd numeric(10,6),
    created_at timestamptz
)
```

