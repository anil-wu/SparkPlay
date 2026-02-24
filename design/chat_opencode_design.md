# ChatPanel 与 OpenCode 集成设计方案

本方案详细说明了如何通过 `@opencode-ai/sdk` 和 `@opencode-ai/ui` 组件包，在容器化环境中实现 ChatPanel 与 OpenCode 的深度集成，支持 AI 驱动的代码开发与图片生成。

## 1. 架构概览

采用 **“胖前端 + 容器化执行环境”** 的架构模式。前端直接管理 AI 会话状态，`opencode` 容器负责重型计算、代码执行和文件操作。

### 1.1 组件交互图
```mermaid
graph TD
    User((用户)) <--> WebApp[React Web App]
    subgraph WebApp
        ChatPanel[ChatPanel Component]
        SDK[@opencode-ai/sdk]
        UIKit[@opencode-ai/ui]
    end
    SDK -- HTTP/WS --> OpenCodeContainer[OpenCode Container]
    subgraph OpenCodeContainer
        Server[OpenCode Server]
        Tools[Code/Image/Bash Tools]
        Workspace[(Shared Workspace)]
    end
    Tools -- Image Gen --> ImageModel[Stable Diffusion / DALL-E]
```

## 2. 前端设计 (React + SDK + UI Kit)

前端利用 `@opencode-ai/sdk` 与 OpenCode 容器通信，并使用 `@opencode-ai/ui` 构建交互界面。

### 2.1 核心依赖
- `@opencode-ai/sdk`: 提供类型安全的 API 客户端。
- `@opencode-ai/ui`: 提供 MessageList, MessageInput, ToolResult 等原子组件。

### 2.2 关键代码实现示例
```tsx
import { createOpencodeClient } from "@opencode-ai/sdk";
import { ChatPanel, MessageList, MessageInput, ToolResult } from "@opencode-ai/ui";
import { useState, useEffect } from "react";

// 1. 初始化 SDK 客户端，指向容器地址
const client = createOpencodeClient({
  baseUrl: "http://localhost:4096",
});

export default function ChatView() {
  const [messages, setMessages] = useState([]);
  const [sessionId, setSessionId] = useState(null);

  // 2. 初始化会话
  useEffect(() => {
    client.session.create().then(res => setSessionId(res.data.id));
  }, []);

  const handleSend = async (text: string) => {
    // 3. 发送 Prompt 到 SDK
    const response = await client.session.prompt({
      path: { id: sessionId },
      body: { parts: [{ type: "text", text }] }
    });

    // 4. 更新 UI 状态
    setMessages(prev => [...prev, response.data]);
  };

  return (
    <div className="chat-container">
      <ChatPanel>
        <MessageList 
          messages={messages} 
          renderTool={(tool) => (
            // 自动根据工具类型渲染 Code Diff 或图片
            <ToolResult tool={tool} />
          )}
        />
        <MessageInput onSend={handleSend} />
      </ChatPanel>
    </div>
  );
}
```

## 3. 容器化部署方案 (Docker Compose)

OpenCode 需要以 `serve` 模式运行，并挂载共享工作目录。

### 3.1 `deploy/docker-compose.yml` 配置
```yaml
services:
  opencode:
    image: ghcr.io/anomalyco/opencode:latest
    container_name: opencode-service
    command: opencode serve --port 4096 --hostname 0.0.0.0
    ports:
      - "4096:4096"
    volumes:
      - ./workspace:/workspace # 代码与图片保存路径
    environment:
      - OPENCODE_CONFIG_PATH=/workspace/opencode.json
      - IMAGE_GEN_API_KEY=${IMAGE_GEN_API_KEY}
    restart: unless-stopped
```

## 4. 核心功能流实现

### 4.1 代码开发流程 (Code Dev)
1. **触发**: 用户在 ChatPanel 输入指令（如：“修改组件样式”）。
2. **执行**: 前端 SDK 将请求转发至容器，OpenCode Agent 调用 `edit_file` 或 `patch` 工具。
3. **响应**: 容器内文件被修改，返回包含工具调用详情的 JSON。
4. **展现**: `@opencode-ai/ui` 的 `ToolResult` 自动渲染 **Code Diff 视图**。

### 4.2 图片生成流程 (Image Gen)
1. **触发**: 用户请求生成素材（如：“生成一个背景图”）。
2. **执行**: OpenCode Agent 调用 `generate_image` 工具（连接远程 MCP 或本地模型）。
3. **存储**: 图片文件（如 `.png`）保存在 `/workspace/assets/` 下。
4. **展现**: 返回结果包含文件路径，`ToolResult` 自动渲染图片预览。

## 5. 设计优势

1. **零后端负担**: 前端通过 SDK 直接驱动 AI 容器，简化了传统 BFF 层的复杂逻辑。
2. **生成式 UI**: 利用 `@opencode-ai/ui` 自动适配多种工具输出（代码、图表、图片）。
3. **开发安全**: 容器化环境天然隔离，代码执行受限，保护宿主机安全。
4. **一致性体验**: 界面组件完全符合 OpenCode 生态标准，交互流畅且功能完善。
