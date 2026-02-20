# WebSocket Chat 消息协议

本文档描述 Agent WebSocket 服务 (`service_ws.py`) 的前后端消息类型和数据结构。

## 连接端点

```
ws://localhost:8001/ws?token=<jwt_token>
```

## 消息格式

所有消息均为 JSON 格式。

---

## 客户端 -> 服务端 消息类型

### 1. ping

心跳检测消息。

```json
{
  "type": "ping"
}
```

**响应**: `pong`

---

### 2. auth

认证消息，用于建立会话身份。

```json
{
  "type": "auth",
  "token": "jwt_token_string",
  "project_id": "project_uuid",
  "user_id": "user_id_string"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| type | string | 是 | 固定值 "auth" |
| token | string | 是 | JWT 认证令牌 |
| project_id | string | 否 | 项目 ID |
| user_id | string | 是 | 用户 ID |

**成功响应**: `auth_ok`

**失败响应**: `error`

---

### 3. message

发送用户消息给 Agent 处理。

```json
{
  "type": "message",
  "request_id": "uuid_string",
  "session_id": "uuid_string",
  "project_id": "project_uuid",
  "text": "用户输入的文本内容",
  "run_mode": "live",
  "mode": "agent"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| type | string | 是 | 固定值 "message" (兼容旧版 "user_message") |
| request_id | string | 否 | 请求唯一标识，不传则自动生成 UUID |
| session_id | string | 否 | 会话 ID，不传则自动生成 UUID |
| project_id | string | 否 | 项目 ID，可覆盖 auth 时的设置 |
| text | string | 是 | 用户输入的文本内容 |
| message_mode | string | 否 | 消息模式: "stream"(流式) 或 "async"(异步)，默认 "stream" |
| mode | string | 否 | Agent 模式: "agent" 或 "skill"，默认 "agent" |

**响应**: 流式返回多个 `event` 消息，最后返回 `completed` 类型

---

### 4. mode

切换 Agent 运行模式。

```json
{
  "type": "mode",
  "mode": "agent"
}
```

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| type | string | 是 | 固定值 "mode" |
| mode | string | 是 | 模式: "agent" 或 "skill" |

**成功响应**: `mode_ok`

---

## 服务端 -> 客户端 消息类型

### 1. pong

心跳响应。

```json
{
  "type": "pong"
}
```

---

### 2. auth_ok

认证成功响应。

```json
{
  "type": "auth_ok",
  "project_id": "project_uuid"
}
```

---

### 3. mode_ok

模式切换成功响应。

```json
{
  "type": "mode_ok",
  "mode": "agent"
}
```

---

### 4. event

Agent 处理过程中的事件消息，流式返回。

```json
{
  "type": "event",
  "request_id": "uuid_string",
  "message_type": "message",
  "content": "事件内容文本",
  "message_id": "uuid_string",
  "author": "agent_name",
  "server_time": 1700000000000,
  "elapsed_ms": 1234
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| type | string | 固定值 "event" |
| request_id | string | 对应的请求 ID |
| message_type | string | 消息子类型 (见下表) |
| content | string | 事件内容 |
| message_id | string | 消息唯一标识 (同类型连续消息共享 ID) |
| author | string | 消息作者 (agent 名称) |
| server_time | number | 服务器时间戳 (毫秒) |
| elapsed_ms | number | 从请求开始经过的毫秒数 |

#### message_type 子类型

| 值 | 说明 |
|------|------|
| message | 普通文本消息 |
| thinking | 思考过程 (内部推理) |
| function_call | 函数调用请求 |
| function_response | 函数调用响应 |
| error | 错误消息 |
| completed | 处理完成标志 |

---

### 5. error

错误消息。

```json
{
  "type": "error",
  "error": "error_code",
  "request_id": "uuid_string",
  "exception": "ExceptionClassName",
  "message": "错误详细信息"
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| type | string | 固定值 "error" |
| error | string | 错误代码 (见下表) |
| request_id | string | 关联的请求 ID (可选) |
| exception | string | 异常类名 (可选) |
| message | string | 错误详细信息 (可选) |

#### 错误代码

| 错误代码 | 说明 |
|------|------|
| invalid_json | JSON 解析失败 |
| invalid_request | 请求格式无效 |
| missing_token | 缺少 token |
| missing_user_id | 缺少 user_id |
| missing_text | 缺少文本内容 |
| not_authenticated | 未认证 |
| agent_config_load_failed | Agent 配置加载失败 |
| auth_failed | 认证失败 |
| run_failed | Agent 运行失败 |
| unsupported_type | 不支持的消息类型 |

---

## 完整通信流程示例

### 1. 建立连接并认证

```
Client -> Server:
{
  "type": "auth",
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "project_id": "proj_123",
  "user_id": "user_456"
}

Server -> Client:
{
  "type": "auth_ok",
  "project_id": "proj_123"
}
```

### 2. 发送消息并接收流式响应

```
Client -> Server:
{
  "type": "message",
  "request_id": "req_001",
  "session_id": "sess_001",
  "text": "帮我创建一个游戏角色"
}

Server -> Client (流式):
{
  "type": "event",
  "request_id": "req_001",
  "message_type": "thinking",
  "content": "正在分析用户需求...",
  "message_id": "msg_001",
  "author": "phaser_agent",
  "server_time": 1700000001000,
  "elapsed_ms": 100
}

{
  "type": "event",
  "request_id": "req_001",
  "message_type": "function_call",
  "content": "{\"name\": \"create_character\", \"args\": {...}}",
  "message_id": "msg_002",
  "author": "phaser_agent",
  "server_time": 1700000002000,
  "elapsed_ms": 1100
}

{
  "type": "event",
  "request_id": "req_001",
  "message_type": "message",
  "content": "我已经为您创建了一个游戏角色...",
  "message_id": "msg_003",
  "author": "phaser_agent",
  "server_time": 1700000003000,
  "elapsed_ms": 2100
}

{
  "type": "event",
  "request_id": "req_001",
  "message_type": "completed",
  "content": "",
  "message_id": "msg_004",
  "author": "phaser_agent",
  "server_time": 1700000003500,
  "elapsed_ms": 2600
}
```

### 3. 心跳检测

```
Client -> Server:
{
  "type": "ping"
}

Server -> Client:
{
  "type": "pong"
}
```

---

## 状态管理

WebSocket 服务维护以下状态:

- `_runner_by_token`: Token -> InMemoryRunner 映射
- `_user_id_by_token`: Token -> user_id 映射
- `_mode_by_token`: Token -> 运行模式映射
- `_session_locks`: (token, user_id, session_id) -> Lock 映射，用于会话并发控制

## Session State 字段

每个 Agent 会话的 state 包含以下字段:

| 字段 | 说明 |
|------|------|
| token | JWT 认证令牌 |
| project_id | 当前项目 ID |
| user_id | 当前用户 ID |
| api_base_url | API 基础 URL |
