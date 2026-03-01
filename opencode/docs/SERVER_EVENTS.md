# OpenCode 服务端事件系统文档

本文档详细说明了 OpenCode 服务端通过 Server-Sent Events (SSE) 发送的所有事件类型、数据结构及其生命周期。

---

## 目录

1. [事件系统概述](#事件系统概述)
2. [事件传输机制](#事件传输机制)
3. [事件分类](#事件分类)
4. [事件详细定义](#事件详细定义)
   - [服务器事件](#服务器事件)
   - [会话事件](#会话事件)
   - [消息事件](#消息事件)
   - [文件事件](#文件事件)
   - [权限事件](#权限事件)
   - [终端事件](#终端事件)
   - [项目事件](#项目事件)
   - [LSP 事件](#LSP 事件)
   - [MCP 事件](#MCP 事件)
   - [TUI 事件](#TUI 事件)
   - [其他事件](#其他事件)
5. [事件生命周期](#事件生命周期)
6. [使用示例](#使用示例)

---

## 事件系统概述

OpenCode 使用基于 Bus 的事件总线系统来管理和分发系统内的各种事件。所有事件都通过 `BusEvent.define()` 进行定义，并通过 `Bus.publish()` 发布。

事件系统特点：
- **统一格式**：所有事件都包含 `type` 和 `properties` 两个字段
- **类型安全**：使用 Zod schema 进行严格的类型验证
- **实时推送**：通过 SSE 向客户端实时推送事件
- **订阅机制**：支持订阅特定事件或所有事件

---

## 事件传输机制

### SSE 端点

OpenCode 提供两个 SSE 端点：

1. **实例级事件端点**: `GET /event`
   - 订阅当前实例的所有事件
   - 连接时发送 `server.connected` 事件
   - 每 10 秒发送心跳事件 `server.heartbeat`
   - 实例销毁时自动关闭连接

2. **全局事件端点**: `GET /global/event`
   - 订阅全局事件（跨所有实例）
   - 连接时发送 `server.connected` 事件
   - 每 10 秒发送心跳事件
   - 事件包装格式：`{ directory: string, payload: Event }`

### 事件格式

标准事件格式：
```typescript
interface Event {
  type: string          // 事件类型标识
  properties: object    // 事件数据
}
```

全局事件包装格式：
```typescript
interface GlobalEvent {
  directory: string     // 项目目录
  payload: Event        // 实际事件
}
```

---

## 事件分类

事件按功能领域分为以下几类：

| 分类 | 事件数量 | 说明 |
|------|---------|------|
| 服务器事件 | 2 | 服务器连接、心跳等系统级事件 |
| 会话事件 | 7 | 会话生命周期管理相关事件 |
| 消息事件 | 5 | 消息和部分（Part）的更新事件 |
| 文件事件 | 2 | 文件编辑和监视器事件 |
| 权限事件 | 4 | 权限请求和响应事件 |
| 终端事件 | 4 | 伪终端生命周期事件 |
| 项目事件 | 2 | 项目和 VCS 相关事件 |
| LSP 事件 | 1 | 语言服务器协议事件 |
| MCP 事件 | 2 | MCP 工具变更事件 |
| TUI 事件 | 4 | 终端用户界面事件 |
| 其他事件 | 9 | 安装、IDE、任务等其他事件 |

---

## 事件详细定义

### 服务器事件

#### 1. server.connected

**触发时机**：客户端连接到 SSE 端点时

**生命周期**：连接建立时立即触发，每个连接只触发一次

**数据结构**：
```typescript
interface ServerConnectedEvent {
  type: "server.connected"
  properties: {}
}
```

**说明**：连接建立的握手事件，不包含额外数据。

---

#### 2. server.heartbeat

**触发时机**：每 10 秒自动发送

**生命周期**：周期性触发，用于保持连接活跃，防止代理流停滞

**数据结构**：
```typescript
interface ServerHeartbeatEvent {
  type: "server.heartbeat"
  properties: {}
}
```

**说明**：心跳事件，用于维持长连接和检测连接状态。

---

#### 3. server.instance.disposed

**触发时机**：实例被销毁时

**生命周期**：实例清理时触发，触发后连接关闭

**数据结构**：
```typescript
interface ServerInstanceDisposedEvent {
  type: "server.instance.disposed"
  properties: {
    directory: string    // 实例目录路径
  }
}
```

**说明**：实例资源释放事件，客户端收到后应关闭连接。

---

### 会话事件

#### 4. session.created

**触发时机**：创建新会话时

**生命周期**：会话创建成功后立即触发 → 可能触发 `session.updated`

**数据结构**：
```typescript
interface SessionCreatedEvent {
  type: "session.created"
  properties: {
    info: Session
  }
}

interface Session {
  id: string              // 会话 ID (格式：ses_xxx)
  slug: string            // 人类可读短标识
  projectID: string       // 项目 ID
  directory: string       // 项目目录
  parentID?: string       // 父会话 ID (fork 产生)
  title: string           // 会话标题
  version: string         // OpenCode 版本
  summary?: {
    additions: number     // 新增行数
    deletions: number     // 删除行数
    files: number         // 修改文件数
    diffs?: FileDiff[]    // 文件变更详情
  }
  share?: {
    url: string           // 分享链接
  }
  permission?: Ruleset    // 权限规则集
  time: {
    created: number       // 创建时间戳
    updated: number       // 更新时间戳
    compacting?: number   // 压缩开始时间戳
    archived?: number     // 归档时间戳
  }
}
```

**说明**：会话创建时触发，包含完整的会话信息。

---

#### 5. session.updated

**触发时机**：会话信息更新时（如标题修改、分享、归档等）

**生命周期**：会话生命周期内可多次触发

**数据结构**：
```typescript
interface SessionUpdatedEvent {
  type: "session.updated"
  properties: {
    info: Session
  }
}
```

**说明**：会话任何字段更新时都会触发。

---

#### 6. session.deleted

**触发时机**：会话被删除时

**生命周期**：会话删除时触发，会话生命周期结束

**数据结构**：
```typescript
interface SessionDeletedEvent {
  type: "session.deleted"
  properties: {
    info: Session
  }
}
```

**说明**：会话被永久删除时触发。

---

#### 7. session.status

**触发时机**：会话状态变化时

**生命周期**：会话活跃期间多次触发

**数据结构**：
```typescript
interface SessionStatusEvent {
  type: "session.status"
  properties: {
    sessionID: string
    status: SessionStatus
  }
}

type SessionStatus = 
  | { type: "idle" }                           // 空闲
  | { type: "retry";                           // 重试中
      attempt: number;
      message: string;
      next: number;
    }
  | { type: "busy" }                           // 忙碌中
```

**说明**：实时反映会话的执行状态。

---

#### 8. session.idle (已废弃)

**触发时机**：会话进入空闲状态时

**生命周期**：会话从忙碌转为空闲时触发

**数据结构**：
```typescript
interface SessionIdleEvent {
  type: "session.idle"
  properties: {
    sessionID: string
  }
}
```

**说明**：已废弃，使用 `session.status` 替代。

---

#### 9. session.compacted

**触发时机**：会话压缩完成时

**生命周期**：会话压缩操作完成后触发

**数据结构**：
```typescript
interface SessionCompactedEvent {
  type: "session.compacted"
  properties: {
    sessionID: string
  }
}
```

**说明**：会话上下文压缩完成，释放 token 空间。

---

#### 10. session.diff

**触发时机**：会话文件变更时

**生命周期**：会话执行过程中产生文件变更时触发

**数据结构**：
```typescript
interface SessionDiffEvent {
  type: "session.diff"
  properties: {
    sessionID: string
    diff: FileDiff[]
  }
}

interface FileDiff {
  path: string              // 文件路径
  additions: number         // 新增行数
  deletions: number         // 删除行数
}
```

**说明**：实时推送会话产生的文件变更。

---

#### 11. session.error

**触发时机**：会话执行出错时

**生命周期**：错误发生时触发

**数据结构**：
```typescript
interface SessionErrorEvent {
  type: "session.error"
  properties: {
    sessionID?: string
    error?: ProviderAuthError | UnknownError | MessageOutputLengthError | MessageAbortedError | ApiError
  }
}
```

**说明**：会话执行过程中的错误信息。

---

### 消息事件

#### 12. message.updated

**触发时机**：消息信息更新时

**生命周期**：消息生命周期内可多次触发，典型触发流程：

```
消息创建 → message.updated (初始创建)
    ↓
[消息处理中]
    ↓
message.updated (更新 tokens/cost)
    ↓
message.updated (更新完成时间 time.completed)
    ↓
message.updated (添加错误信息 error)
    ↓
message.updated (添加结构化输出)
```

**详细触发场景**：

| 场景 | 触发原因 | 更新字段 |
|------|---------|---------|
| 消息创建 | 创建用户/助手消息 | 所有初始字段 |
| Token 统计 | 模型调用完成后更新 token 使用量 | `tokens`、`cost` |
| 消息完成 | 消息处理完成 | `time.completed`、`finish` |
| 错误发生 | 模型调用或处理出错 | `error`、`abort` |
| 结构化输出 | 产生结构化输出结果 | `structured` |
| 摘要更新 | 更新消息摘要信息 | `summary` |
| 命令执行 | 执行命令时更新消息状态 | 消息状态字段 |

**数据结构**：
```typescript
interface MessageUpdatedEvent {
  type: "message.updated"
  properties: {
    info: Message
  }
}

type Message = UserMessage | AssistantMessage

interface UserMessage {
  id: string
  sessionID: string
  role: "user"
  time: { created: number }
  format?: OutputFormat
  summary?: {
    title?: string
    body?: string
    diffs: FileDiff[]
  }
  agent: string
  model: {
    providerID: string
    modelID: string
  }
  tokens: {
    input: number
    output: number
    cache: { read: number; write: number }
  }
  cost: number
}

interface AssistantMessage {
  id: string
  sessionID: string
  role: "assistant"
  parentID?: string
  time: { created: number }
  summary?: { title?: string }
  error?: ErrorInfo
  abort?: boolean
  agent: string
  model: { providerID: string; modelID: string }
  tokens: {
    input: number
    output: number
    cache: { read: number; write: number }
    total?: number
  }
  cost: number
  // 内部字段（不总是发送到客户端）
  finish?: "stop" | "tool-calls"
  structured?: object
  time?: { completed?: number }
}
```

**说明**：
- 每次调用 `Session.updateMessage()` 时触发
- 通常与 `message.part.delta` 和 `message.part.updated` 配合使用
- 在消息的完整生命周期中可能触发 3-5 次：
  1. 初始创建
  2. 开始流式输出（设置状态）
  3. 完成输出（设置完成时间）
  4. 更新 token 统计
  5. 发生错误时（设置错误信息）

**代码示例**：
```typescript
// 创建消息时触发
const msg = await Session.updateMessage({
  id: Identifier.ascending("message"),
  role: "assistant",
  sessionID: session.id,
  time: { created: Date.now() },
  agent: "default",
  model: { providerID: "anthropic", modelID: "claude-3-5-sonnet" }
})
// → 触发 message.updated

// 更新完成时间
msg.time.completed = Date.now()
await Session.updateMessage(msg)
// → 再次触发 message.updated

// 更新错误信息
msg.error = { name: "APIError", message: "Rate limit" }
await Session.updateMessage(msg)
// → 第三次触发 message.updated
```

---

#### 13. message.removed

**触发时机**：消息被删除时

**生命周期**：消息删除时触发

**数据结构**：
```typescript
interface MessageRemovedEvent {
  type: "message.removed"
  properties: {
    sessionID: string
    messageID: string
  }
}
```

**说明**：消息被永久删除。

---

#### 14. message.part.updated

**触发时机**：消息部分（Part）更新时

**生命周期**：Part 生命周期内可多次触发

**数据结构**：
```typescript
interface MessagePartUpdatedEvent {
  type: "message.part.updated"
  properties: {
    part: Part
  }
}

type Part = TextPart | ToolPart | ReasoningPart | OutputPart

interface TextPart {
  id: string
  type: "text"
  state: {
    status: "pending" | "generating" | "completed"
    text: string
    time: { started?: number; completed?: number }
  }
}

interface ToolPart {
  id: string
  type: "tool"
  tool: string
  state: {
    status: "pending" | "executing" | "completed" | "failed"
    input: object
    output: string | object
    time: { started?: number; completed?: number; compacted?: number }
  }
}

interface ReasoningPart {
  id: string
  type: "reasoning"
  state: {
    status: "pending" | "generating" | "completed"
    text: string
    time: { started?: number; completed?: number }
  }
}
```

**说明**：Part 内容或状态更新时触发。

---

#### 15. message.part.delta

**触发时机**：消息部分增量更新时（流式输出）

**生命周期**：Part 生成过程中频繁触发

**数据结构**：
```typescript
interface MessagePartDeltaEvent {
  type: "message.part.delta"
  properties: {
    sessionID: string
    messageID: string
    partID: string
    field: string         // 更新的字段名
    delta: string         // 增量内容
  }
}
```

**说明**：实时推送 Part 的增量内容，用于流式显示。

---

#### 16. message.part.removed

**触发时机**：消息部分被删除时

**生命周期**：Part 删除时触发

**数据结构**：
```typescript
interface MessagePartRemovedEvent {
  type: "message.part.removed"
  properties: {
    sessionID: string
    messageID: string
    partID: string
  }
}
```

**说明**：Part 被永久删除。

---

### 文件事件

#### 17. file.edited

**触发时机**：文件被编辑时

**生命周期**：文件写入操作完成后触发

**数据结构**：
```typescript
interface FileEditedEvent {
  type: "file.edited"
  properties: {
    file: string          // 文件路径
  }
}
```

**说明**：OpenCode 主动编辑文件时触发。

---

#### 18. file.watcher.updated

**触发时机**：文件系统监视器检测到变化时

**生命周期**：文件变化时实时触发

**数据结构**：
```typescript
interface FileWatcherUpdatedEvent {
  type: "file.watcher.updated"
  properties: {
    file: string          // 文件路径
    event: "add" | "change" | "unlink"
  }
}
```

**说明**：外部文件变化（非 OpenCode 编辑）时触发。

---

### 权限事件

#### 19. permission.asked

**触发时机**：需要用户授权时

**生命周期**：权限请求发出 → 等待用户响应 → `permission.replied`

**数据结构**：
```typescript
interface PermissionAskedEvent {
  type: "permission.asked"
  properties: {
    id: string            // 权限请求 ID
    sessionID: string
    messageID: string
    permission: string    // 权限类型
    patterns: string[]    // 请求的模式
    always: string[]      // 永久授权的模式
    callID?: string       // 工具调用 ID
    metadata: object
  }
}
```

**说明**：需要用户确认权限时触发。

---

#### 20. permission.replied

**触发时机**：用户响应权限请求时

**生命周期**：用户做出选择后触发

**数据结构**：
```typescript
interface PermissionRepliedEvent {
  type: "permission.replied"
  properties: {
    sessionID: string
    permissionID: string
    response: string      // 用户选择：once/always/reject
  }
}
```

**说明**：用户对权限请求的响应。

---

#### 21. permission.updated

**触发时机**：权限信息更新时

**生命周期**：权限状态变化时触发

**数据结构**：
```typescript
interface PermissionUpdatedEvent {
  type: "permission.updated"
  properties: Permission
}

interface Permission {
  id: string
  sessionID: string
  messageID: string
  type: string
  message: string
  pattern?: string
  callID?: string
  metadata: object
}
```

**说明**：权限信息更新。

---

#### 22. permission.asked (Next)

**触发时机**：新权限系统请求授权时

**生命周期**：权限请求 → 用户响应 → `permission.replied` (Next)

**数据结构**：
```typescript
interface PermissionAskedNextEvent {
  type: "permission.asked"
  properties: {
    id: string
    sessionID: string
    messageID: string
    permission: string
    patterns: string[]
    always: string[]
    ruleset: Ruleset
  }
}
```

**说明**：新权限系统的授权请求。

---

#### 23. permission.replied (Next)

**触发时机**：用户响应新权限系统请求时

**数据结构**：
```typescript
interface PermissionRepliedNextEvent {
  type: "permission.replied"
  properties: {
    sessionID: string
    requestID: string
    reply: "once" | "always" | "reject"
  }
}
```

**说明**：新权限系统的用户响应。

---

### 终端事件

#### 24. pty.created

**触发时机**：创建新的伪终端时

**生命周期**：终端创建成功 → 可能多次 `pty.updated` → `pty.exited` → `pty.deleted`

**数据结构**：
```typescript
interface PtyCreatedEvent {
  type: "pty.created"
  properties: {
    info: Pty
  }
}

interface Pty {
  id: string              // 终端 ID
  title: string           // 终端标题
  command: string         // 命令
  args: string[]          // 参数
  cwd: string             // 工作目录
  status: "running" | "exited"
  pid: number             // 进程 ID
}
```

**说明**：终端会话创建成功。

---

#### 25. pty.updated

**触发时机**：终端信息更新时

**生命周期**：终端生命周期内可多次触发

**数据结构**：
```typescript
interface PtyUpdatedEvent {
  type: "pty.updated"
  properties: {
    info: Pty
  }
}
```

**说明**：终端信息（如标题、状态）更新。

---

#### 26. pty.exited

**触发时机**：终端进程退出时

**生命周期**：进程退出 → 随后触发 `pty.deleted`

**数据结构**：
```typescript
interface PtyExitedEvent {
  type: "pty.exited"
  properties: {
    id: string
    exitCode: number      // 退出码
  }
}
```

**说明**：终端进程结束。

---

#### 27. pty.deleted

**触发时机**：终端被删除时

**生命周期**：终端资源清理时触发，终端生命周期结束

**数据结构**：
```typescript
interface PtyDeletedEvent {
  type: "pty.deleted"
  properties: {
    id: string
  }
}
```

**说明**：终端资源被清理。

---

### 项目事件

#### 28. project.updated

**触发时机**：项目信息更新时

**生命周期**：项目信息变化时触发

**数据结构**：
```typescript
interface ProjectUpdatedEvent {
  type: "project.updated"
  properties: Project
}

interface Project {
  id: string
  worktree: string
  vcsDir?: string
  vcs?: "git"
  name?: string
  icon?: {
    url?: string
    color?: string
  }
  time: {
    created: number
    initialized?: number
  }
  sandboxes?: object
  commands?: object
}
```

**说明**：项目配置或状态更新。

---

#### 29. vcs.branch.updated

**触发时机**：VCS 分支变化时

**生命周期**：Git 分支切换时触发

**数据结构**：
```typescript
interface VcsBranchUpdatedEvent {
  type: "vcs.branch.updated"
  properties: {
    branch?: string       // 新分支名
  }
}
```

**说明**：Git 分支变更通知。

---

### LSP 事件

#### 30. lsp.client.diagnostics

**触发时机**：LSP 诊断信息更新时

**生命周期**：诊断更新时频繁触发

**数据结构**：
```typescript
interface LspClientDiagnosticsEvent {
  type: "lsp.client.diagnostics"
  properties: {
    serverID: string      // LSP 服务器 ID
    path: string          // 文件路径
  }
}
```

**说明**：语言服务器诊断信息（错误、警告等）更新。

---

#### 31. lsp.updated

**触发时机**：LSP 状态更新时

**数据结构**：
```typescript
interface LspUpdatedEvent {
  type: "lsp.updated"
  properties: {}
}
```

**说明**：LSP 服务状态更新。

---

### MCP 事件

#### 32. mcp.tools.changed

**触发时机**：MCP 工具列表变化时

**生命周期**：MCP 服务器工具变更时触发

**数据结构**：
```typescript
interface McpToolsChangedEvent {
  type: "mcp.tools.changed"
  properties: {
    server: string        // MCP 服务器名称
  }
}
```

**说明**：MCP 工具列表变更通知。

---

#### 33. mcp.browser.open.failed

**触发时机**：MCP 浏览器打开失败时

**数据结构**：
```typescript
interface McpBrowserOpenFailedEvent {
  type: "mcp.browser.open.failed"
  properties: {
    mcpName: string
    url: string
  }
}
```

**说明**：MCP 浏览器操作失败。

---

### TUI 事件

#### 34. tui.prompt.append

**触发时机**：TUI 提示符追加文本时

**数据结构**：
```typescript
interface TuiPromptAppendEvent {
  type: "tui.prompt.append"
  properties: {
    text: string
  }
}
```

**说明**：终端界面提示符文本追加。

---

#### 35. tui.command.execute

**触发时机**：TUI 命令执行时

**数据结构**：
```typescript
interface TuiCommandExecuteEvent {
  type: "tui.command.execute"
  properties: {
    command: string       // 命令名称
  }
}
```

**说明**：终端界面命令执行。

---

#### 36. tui.toast.show

**触发时机**：显示 TUI 提示消息时

**数据结构**：
```typescript
interface TuiToastShowEvent {
  type: "tui.toast.show"
  properties: {
    title?: string
    message: string
    variant: "info" | "success" | "warning" | "error"
    duration?: number     // 持续时间（毫秒）
  }
}
```

**说明**：终端界面弹出提示。

---

#### 37. tui.session.select

**触发时机**：TUI 选择会话时

**数据结构**：
```typescript
interface TuiSessionSelectEvent {
  type: "tui.session.select"
  properties: {
    sessionID: string
  }
}
```

**说明**：终端界面会话选择。

---

### 其他事件

#### 38. installation.updated

**触发时机**：OpenCode 安装版本更新时

**数据结构**：
```typescript
interface InstallationUpdatedEvent {
  type: "installation.updated"
  properties: {
    version: string       // 新版本号
  }
}
```

**说明**：安装版本更新。

---

#### 39. installation.update-available

**触发时机**：有新版本可用时

**数据结构**：
```typescript
interface InstallationUpdateAvailableEvent {
  type: "installation.update-available"
  properties: {
    version: string       // 可用新版本号
  }
}
```

**说明**：更新可用通知。

---

#### 40. ide.installed

**触发时机**：IDE 扩展安装完成时

**数据结构**：
```typescript
interface IdeInstalledEvent {
  type: "ide.installed"
  properties: {
    ide: string           // IDE 名称
  }
}
```

**说明**：IDE 扩展安装成功。

---

#### 41. todo.updated

**触发时机**：任务列表更新时

**数据结构**：
```typescript
interface TodoUpdatedEvent {
  type: "todo.updated"
  properties: {
    sessionID: string
    todos: Todo[]
  }
}

interface Todo {
  content: string         // 任务内容
  status: string          // pending/in_progress/completed/cancelled
  priority: string        // high/medium/low
}
```

**说明**：任务列表变更。

---

#### 42. command.executed

**触发时机**：命令执行完成时

**数据结构**：
```typescript
interface CommandExecutedEvent {
  type: "command.executed"
  properties: {
    name: string          // 命令名称
    sessionID: string
    arguments: string     // 命令参数
    messageID: string
  }
}
```

**说明**：命令执行完成。

---

#### 43. question.asked

**触发时机**：系统向用户提问时

**数据结构**：
```typescript
interface QuestionAskedEvent {
  type: "question.asked"
  properties: {
    id: string
    sessionID: string
    questions: Question[]
    tool?: {
      messageID: string
      callID: string
    }
  }
}

interface Question {
  question: string
  options: string[]
  multiple: boolean
}
```

**说明**：系统请求用户回答问题。

---

#### 44. question.replied

**触发时机**：用户回答问题时

**数据结构**：
```typescript
interface QuestionRepliedEvent {
  type: "question.replied"
  properties: {
    sessionID: string
    requestID: string
    answers: Answer[]
  }
}

interface Answer {
  question: string
  labels: string[]
}
```

**说明**：用户对问题的回答。

---

#### 45. question.rejected

**触发时机**：用户拒绝回答问题时

**数据结构**：
```typescript
interface QuestionRejectedEvent {
  type: "question.rejected"
  properties: {
    sessionID: string
    requestID: string
  }
}
```

**说明**：用户拒绝回答问题。

---

#### 46. worktree.ready

**触发时机**：工作树准备就绪时

**数据结构**：
```typescript
interface WorktreeReadyEvent {
  type: "worktree.ready"
  properties: {
    name: string
    branch: string
  }
}
```

**说明**：工作树初始化完成。

---

#### 47. worktree.failed

**触发时机**：工作树操作失败时

**数据结构**：
```typescript
interface WorktreeFailedEvent {
  type: "worktree.failed"
  properties: {
    message: string
  }
}
```

**说明**：工作树操作失败。

---

#### 48. global.disposed

**触发时机**：全局实例被销毁时

**数据结构**：
```typescript
interface GlobalDisposedEvent {
  type: "global.disposed"
  properties: {}
}
```

**说明**：全局资源清理。

---

## 事件生命周期

### 典型事件生命周期流程

#### 会话完整生命周期

```
session.created
    ↓
[session.updated] × N          (会话信息更新)
    ↓
[session.status: busy]         (开始执行)
    ↓
┌─────────────────────────────────────┐
│ 消息循环（每轮对话）                  │
├─────────────────────────────────────┤
│ 1. 用户消息：                        │
│    message.updated (创建)            │
│                                      │
│ 2. 助手响应：                        │
│    message.updated (创建助手消息)    │
│    ↓                                 │
│    message.part.delta × N (流式)    │
│    ↓                                 │
│    message.part.updated × N         │
│    ↓                                 │
│    message.updated (更新 tokens)    │
│    ↓                                 │
│    message.updated (设置完成时间)    │
│    ↓                                 │
│    [可能触发 tool 相关事件]           │
└─────────────────────────────────────┘
    ↓
[session.status: idle]         (执行完成)
    ↓
session.deleted                (会话删除)
```

#### 消息详细生命周期

```
message.updated (初始创建)
    ↓
[开始处理消息]
    ↓
message.part.updated (添加 Part)
    ↓
message.part.delta × N (流式输出内容)
    ↓
message.part.updated (Part 完成)
    ↓
message.updated (更新 token 统计)
    ↓
message.updated (设置 time.completed)
    ↓
[如果发生错误]
    ↓
message.updated (设置 error 字段)
    ↓
[如果执行工具]
    ↓
message.updated (设置 finish: "tool-calls")
```

#### message.updated 触发时机详解

| 序号 | 触发时机 | 更新内容 | 是否必需 |
|------|---------|---------|---------|
| 1 | 消息创建 | 基本信息（id、role、sessionID 等） | ✓ |
| 2 | 开始流式输出 | 设置初始状态 | ✓ |
| 3 | Part 添加/更新 | 关联 Part 信息 | ✓ |
| 4 | Token 统计 | `tokens`、`cost` | ✓ |
| 5 | 完成时间 | `time.completed` | ✓ |
| 6 | 错误处理 | `error`、`abort` | 可选 |
| 7 | 结构化输出 | `structured` | 可选 |
| 8 | 工具调用 | `finish: "tool-calls"` | 可选 |

**典型触发次数**：
- 简单消息（无错误）：3-4 次
- 复杂消息（有工具调用）：5-7 次
- 错误消息：4-6 次

#### 权限请求生命周期

```
permission.asked
    ↓
[等待用户响应]
    ↓
permission.replied             (用户选择：once/always/reject)
    ↓
[permission.updated]           (权限信息更新)
```

#### 终端生命周期

```
pty.created
    ↓
[pty.updated] × N              (终端信息更新)
    ↓
pty.exited                     (进程退出)
    ↓
pty.deleted                    (资源清理)
```

#### 文件变更生命周期

```
file.edited                    (OpenCode 编辑)
    或
file.watcher.updated           (外部变更)
    ↓
session.diff                   (会话差异更新)
```

---

## 使用示例

### 订阅所有事件

```typescript
const events = await sdk.event.subscribe()

for await (const event of events.stream) {
  console.log("Event:", event.type, event.properties)
}
```

### 订阅全局事件

```typescript
const events = await sdk.global.event.subscribe()

for await (const event of events.stream) {
  console.log("Global Event from", event.directory, event.payload)
}
```

### 过滤特定事件

```typescript
const events = await sdk.event.subscribe()

for await (const event of events.stream) {
  if (event.type === "session.created") {
    console.log("New session created:", event.properties.info)
  }
  
  if (event.type === "message.part.delta") {
    console.log("Streaming:", event.properties.delta)
  }
}
```

### 处理错误事件

```typescript
const events = await sdk.event.subscribe()

for await (const event of events.stream) {
  if (event.type === "session.error") {
    console.error("Session error:", event.properties.error)
  }
}
```

---

## 总结

OpenCode 事件系统提供了 48 种不同的事件类型，覆盖了：

- **服务器管理**：连接、心跳、实例生命周期
- **会话管理**：创建、更新、删除、状态变化
- **消息流**：消息和 Part 的完整生命周期
- **文件系统**：编辑和监视
- **权限控制**：请求和响应
- **终端管理**：PTY 会话管理
- **项目配置**：项目和 VCS 信息
- **开发工具**：LSP、MCP 集成
- **用户界面**：TUI 交互
- **系统通知**：安装、IDE、任务等

所有事件都遵循统一的格式和类型安全的设计，通过 SSE 实时推送，支持客户端构建响应式的用户体验。
