# 六、Agent 与模型映射

### 12. agent

```sql
agent (
    id bigint PK,
    name varchar,
    description text,
    agent_type enum(code, asset, design, test, build, ops),
    created_at timestamptz
)
```

### 13. agent_llm_binding

```sql
agent_llm_binding (
    id bigint PK,
    agent_id bigint FK -> agent.id,
    llm_model_id bigint FK -> llm_model.id,
    priority int,
    is_active boolean,
    created_at timestamptz
)
```

