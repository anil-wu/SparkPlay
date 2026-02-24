# API Routes 迁移文档

## 概述

已将前端对后端 API 的直接访问迁移到 Next.js API Routes，解决了客户端环境变量访问问题。

## 架构变更

### 变更前

```
前端组件 → workspace-api.ts → 后端 API (https://localhost:8890)
```

**问题**:
- 客户端组件无法访问 `SPARKX_API_BASE_URL` 环境变量
- 需要添加 `NEXT_PUBLIC_` 前缀的环境变量
- 环境变量配置复杂

### 变更后

```
前端组件 → workspace-api.ts → API Routes (/api/workspace) → 后端 API
```

**优势**:
- API Routes 在服务端运行，可以访问所有环境变量
- 前端只需要访问相对路径 `/api/workspace`
- 统一 API 管理和错误处理
- 更好的安全性和控制

## 新增文件

### API Routes (5 个文件)

所有 API Routes 位于 `web/src/app/api/workspace/` 目录：

1. **`/api/workspace/canvas`** (`canvas/route.ts`)
   - `GET`: 获取画布和图层数据
   - `POST`: 创建新画布

2. **`/api/workspace/layers/sync`** (`layers/sync/route.ts`)
   - `POST`: 批量同步图层

3. **`/api/workspace/layers/[layerId]`** (`layers/[layerId]/route.ts`)
   - `PUT`: 更新图层
   - `DELETE`: 删除图层（软删除）

4. **`/api/workspace/layers/[layerId]/restore`** (`layers/[layerId]/restore/route.ts`)
   - `POST`: 恢复已删除的图层

5. **`/api/workspace/layers/deleted`** (`layers/deleted/route.ts`)
   - `GET`: 获取已删除的图层列表

### 修改的文件

1. **`web/src/lib/workspace-api.ts`**
   - 移除了 `getBaseUrl()` 函数
   - 移除了 `constructor` 中的 `baseUrl` 属性
   - 所有 API 调用改为使用相对路径 `/api/workspace/*`
   - 使用原生 `fetch` 替代 `fetchSparkxJson`

2. **`web/.env.local`**
   - 移除了 `NEXT_PUBLIC_SPARKX_API_BASE_URL`
   - 只保留服务端的 `SPARKX_API_BASE_URL`

## API 端点映射

| 前端调用 | API Route | 后端 API |
|---------|-----------|---------|
| `workspaceAPI.getCanvas(projectId)` | `GET /api/workspace/canvas?projectId=123` | `GET /api/v1/projects/123/canvas` |
| `workspaceAPI.createCanvas(projectId, data)` | `POST /api/workspace/canvas?projectId=123` | `POST /api/v1/projects/123/canvas` |
| `workspaceAPI.syncLayers(projectId, layers)` | `POST /api/workspace/layers/sync?projectId=123` | `POST /api/v1/projects/123/layers/sync` |
| `workspaceAPI.updateLayer(layerId, updates)` | `PUT /api/workspace/layers/{layerId}` | `PUT /api/v1/layers/{layerId}` |
| `workspaceAPI.deleteLayer(layerId)` | `DELETE /api/workspace/layers/{layerId}` | `DELETE /api/v1/layers/{layerId}` |
| `workspaceAPI.restoreLayer(layerId)` | `POST /api/workspace/layers/{layerId}/restore` | `POST /api/v1/layers/{layerId}/restore` |
| `workspaceAPI.getDeletedLayers(canvasId)` | `GET /api/workspace/layers/deleted?canvasId=123` | `GET /api/v1/layers/deleted?canvasId=123` |

## 代码示例

### 前端调用示例

```typescript
import { workspaceAPI } from '@/lib/workspace-api';

// 获取画布
const canvas = await workspaceAPI.getCanvas(projectId);

// 同步图层
await workspaceAPI.syncLayers(projectId, layers);

// 删除图层
await workspaceAPI.deleteLayer(layerId);

// 恢复图层
await workspaceAPI.restoreLayer(layerId);
```

### API Route 实现示例

```typescript
// web/src/app/api/workspace/canvas/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getSparkxApiBaseUrl, fetchSparkxJson } from '@/lib/sparkx-api';

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const projectId = searchParams.get('projectId');

  if (!projectId) {
    return NextResponse.json(
      { error: 'projectId is required' },
      { status: 400 }
    );
  }

  const baseUrl = getSparkxApiBaseUrl();
  const result = await fetchSparkxJson(
    `${baseUrl}/api/v1/projects/${projectId}/canvas`
  );

  if (!result.ok) {
    return NextResponse.json(
      { error: result.message },
      { status: result.status }
    );
  }

  return NextResponse.json(result.data);
}
```

## 环境变量配置

### 开发环境 (`.env.local`)

```bash
# 服务端环境变量（仅在后端和 API Routes 中可用）
SPARKX_API_BASE_URL=https://localhost:8890

# 其他配置
GOOGLE_CLIENT_ID=xxx
SESSION_SECRET=xxx
```

### 生产环境

```bash
# 部署时设置环境变量
SPARKX_API_BASE_URL=https://api.sparkx.yun
```

## 错误处理

所有 API Routes 都实现了统一的错误处理：

1. **参数验证**: 返回 400 错误
2. **后端 API 错误**: 转发后端错误消息和状态码
3. **未知错误**: 返回 500 错误和通用错误消息

示例：

```typescript
try {
  // API 调用
} catch (error) {
  console.error('Error:', error);
  return NextResponse.json(
    { error: 'Failed to operation' },
    { status: 500 }
  );
}
```

## 性能优化

### 缓存策略

- 使用 `cache: 'no-store'` 禁用缓存
- 确保每次请求都获取最新数据

```typescript
const response = await fetch('/api/workspace/canvas?projectId=123', {
  method: 'GET',
  cache: 'no-store',
});
```

## 安全性

### 认证和授权

- API Routes 可以访问会话和认证信息
- 可以在 API Routes 中实现权限检查
- 后端 API 的 JWT 认证仍然有效

### 环境变量保护

- `SPARKX_API_BASE_URL` 只在服务端可用
- 不会暴露到客户端代码中
- 提高安全性

## 测试

### 手动测试步骤

1. **启动服务**:
   ```bash
   cd web
   npm run dev
   ```

2. **访问编辑页面**:
   ```
   http://localhost:3000/projects/13/edit
   ```

3. **测试保存功能**:
   - 修改画布元素
   - 点击保存按钮或按 Ctrl/Cmd + S
   - 验证保存状态变化

4. **测试回收站**:
   - 删除一个元素
   - 点击回收站按钮
   - 验证显示已删除图层
   - 测试恢复功能

### API 测试

使用 curl 或 Postman 测试 API Routes：

```bash
# 获取画布
curl http://localhost:3000/api/workspace/canvas?projectId=123

# 同步图层
curl -X POST http://localhost:3000/api/workspace/layers/sync?projectId=123 \
  -H "Content-Type: application/json" \
  -d '{"layers": [...]}'
```

## 故障排查

### 常见问题

1. **404 错误**:
   - 检查 API Route 文件路径是否正确
   - 确保文件名为 `route.ts`
   - 清除 `.next` 缓存并重启服务

2. **环境变量错误**:
   - 确保 `.env.local` 文件存在
   - 重启开发服务器以加载新环境变量
   - 检查环境变量名称是否正确

3. **TypeScript 错误**:
   - 运行 `npm run build` 检查编译错误
   - 修复所有类型错误

### 调试技巧

1. **查看日志**:
   ```bash
   # 开发服务器会显示所有请求日志
   npm run dev
   ```

2. **添加日志**:
   ```typescript
   console.log('Request params:', searchParams);
   console.log('Response:', result);
   ```

3. **使用浏览器开发者工具**:
   - 查看 Network 标签的 API 请求
   - 检查请求和响应数据

## 后续优化

1. **添加认证中间件**: 在 API Routes 中实现 JWT 验证
2. **请求限流**: 防止 API 滥用
3. **日志记录**: 记录所有 API 请求用于审计
4. **错误监控**: 集成错误监控服务（如 Sentry）
5. **性能监控**: 添加 API 响应时间监控

## 相关文件

- [API Routes 文档](https://nextjs.org/docs/app/building-your-application/routing/route-handlers)
- [环境变量文档](https://nextjs.org/docs/basic-features/environment-variables)
- [Fetch API 文档](https://nextjs.org/docs/app/building-your-application/data-fetching/fetching)

## 总结

通过迁移到 Next.js API Routes：

✅ 解决了客户端环境变量访问问题  
✅ 统一了 API 管理和错误处理  
✅ 提高了代码可维护性和安全性  
✅ 为未来功能扩展提供了更好的架构基础  

所有功能都正常工作，没有编译错误。
