# 环境变量配置修复

## 问题描述

访问 `http://localhost:3000/projects/13/edit` 时出现错误：
```
Error: Missing required environment variable: SPARKX_API_BASE_URL
```

## 原因分析

1. `workspace-api.ts` 在客户端组件中被调用
2. 客户端组件无法访问服务端环境变量 `SPARKX_API_BASE_URL`
3. 需要添加 `NEXT_PUBLIC_` 前缀的环境变量供客户端使用

## 解决方案

### 1. 添加客户端环境变量

在 `web/.env.local` 文件中添加：

```bash
# 服务端环境变量
SPARKX_API_BASE_URL=https://localhost:8890

# 客户端环境变量（必须有 NEXT_PUBLIC_ 前缀）
NEXT_PUBLIC_SPARKX_API_BASE_URL=https://localhost:8890
```

### 2. 修改 workspace-api.ts 添加容错处理

```typescript
const getBaseUrl = (): string => {
  try {
    return getSparkxApiBaseUrl();
  } catch (error) {
    // Fallback for client-side
    return process.env.NEXT_PUBLIC_SPARKX_API_BASE_URL || 'http://localhost:8001';
  }
};

export class WorkspaceAPI {
  private baseUrl: string;

  constructor() {
    this.baseUrl = getBaseUrl();
  }
}
```

## 环境变量说明

### 服务端环境变量（Server-side only）

- `SPARKX_API_BASE_URL` - 仅在服务端可用
- 用于 Next.js API Routes 和服务端组件
- 不能在客户端代码中直接访问

### 客户端环境变量（Client-side）

- `NEXT_PUBLIC_SPARKX_API_BASE_URL` - 在客户端和服务端都可用
- 必须以 `NEXT_PUBLIC_` 开头
- 会被打包到客户端 JavaScript 中

## 修改的文件

1. **web/.env.local**
   - 添加了 `NEXT_PUBLIC_SPARKX_API_BASE_URL`

2. **web/src/lib/workspace-api.ts**
   - 添加了 `getBaseUrl()` 函数
   - 添加了 try-catch 容错处理
   - 使用 fallback 值

## 重启开发服务器

修改环境变量后需要重启 Next.js 开发服务器：

```bash
cd web
npm run dev
```

## 验证

访问 `http://localhost:3000/projects/13/edit` 应该不再报错，并且：

1. 页面正常加载
2. 保存按钮显示在右上角
3. 回收站按钮显示在保存按钮旁边
4. 可以正常使用保存功能（Ctrl/Cmd + S）

## 注意事项

### 生产环境部署

在生产环境中，需要设置相应的环境变量：

```bash
# .env.production
SPARKX_API_BASE_URL=https://api.sparkx.yun
NEXT_PUBLIC_SPARKX_API_BASE_URL=https://api.sparkx.yun
```

### Docker 部署

如果使用 Docker，通过环境变量传递：

```dockerfile
ENV SPARKX_API_BASE_URL=https://api.sparkx.yun
ENV NEXT_PUBLIC_SPARKX_API_BASE_URL=https://api.sparkx.yun
```

### 不同环境配置

可以创建多个环境配置文件：

- `.env.development` - 开发环境
- `.env.test` - 测试环境
- `.env.production` - 生产环境
- `.env.local` - 本地覆盖（不提交到 Git）

## 相关文件

- [环境变量文档](https://nextjs.org/docs/basic-features/environment-variables)
- [workspace-api.ts](../../web/src/lib/workspace-api.ts)
- [.env.local](../../web/.env.local)
