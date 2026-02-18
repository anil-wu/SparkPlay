# Workspace Manager Agent Tools 设计文档

> **状态**: 已实现  
> **实现文件**: `agents/phaser_agent/tools/work_space_manager.py`

## check_workspace_status 工具设计

### 功能概述
检查工作空间状态，包括凭证验证、远程项目信息获取、远程版本信息获取、本地工作空间检查，并返回完整的状态信息。

### 执行步骤

#### 1. 检查必要凭证
检查以下凭证是否存在：
- `project_id` - 项目 ID
- `user_id` - 用户 ID
- `token` - 认证令牌
- `api_base_url` - API 基础 URL

如果任一凭证缺失，返回错误信息。

#### 2. 获取远程项目信息
调用 API 获取远程项目详情：
```
GET /api/v1/projects/{project_id}
Headers: Authorization: Bearer {token}
```

返回项目基本信息（名称、描述、状态等）。

#### 3. 获取远程最新软件工程版本信息
流程：
```
1. GET /api/v1/projects/{project_id}/files
   └── 查找 name="manifest.json" 的文件，获取 file_id

2. GET /api/v1/files/{file_id}/versions
   └── 返回版本列表（按时间倒序，第一个是最新的）
       └── 取 list[0] 获取最新版本信息
```

返回的版本信息结构：
```json
{
    "file_id": 123,
    "version_id": 456,
    "version_number": 5,
    "hash": "abc123...",
    "size_bytes": 1024,
    "created_at": "2024-01-15T10:30:00Z",
    "created_by": 789
}
```

#### 4. 检查本地工作空间和软件工程
- 检查 `workspace_dir` 是否存在
- 检查 `workspace_game_dir` 是否存在
- 扫描 `workspace_game_dir` 下的子目录，查找包含 `manifest.json` 的软件工程
- 读取本地 `manifest.json` 内容

#### 5. 准备状态信息并返回

### 返回数据结构

```json
{
    "status": "success" | "error",
    "status_code": 200 | 400 | 404,
    "message": "状态描述",
    "data": {
        // 凭证状态
        "has_project_id": true,
        "has_user_id": true,
        "has_token": true,
        "has_api_base_url": true,

        // 远程信息
        "remote_project_info": { ... },
        "remote_project_error": null,
        "remote_manifest_info": {
            "file_id": 123,
            "version_id": 456,
            "version_number": 5,
            "hash": "abc123...",
            "size_bytes": 1024,
            "created_at": "...",
            "created_by": 789
        },
        "remote_manifest_error": null,

        // 本地状态
        "has_workspace": true,
        "has_software": true,
        "workspace_dir": "/path/to/workspace",
        "workspace_game_dir": "/path/to/workspace/game",
        "workspace_artifacts_dir": "/path/to/workspace/artifacts",
        "workspace_build_dir": "/path/to/workspace/build",
        "workspace_logs_dir": "/path/to/workspace/logs",
        "local_software_name": "my-game",
        "local_manifest": { ... },

        // 版本对比
        "version_synced": false,
        "local_version": "1.0.0",
        "remote_version_number": 5
    }
}
```

### 依赖的 API 端点

| 端点 | 方法 | 用途 | 状态 |
|------|------|------|------|
| `/api/v1/projects/{id}` | GET | 获取项目详情 | 已实现 |
| `/api/v1/projects/{projectId}/files` | GET | 获取项目文件列表 | 已实现 |
| `/api/v1/files/{id}/versions` | GET | 获取文件版本列表 | 已实现 |

### State 读写

**读取的 State 字段：**
- `project_id`
- `user_id`
- `token`
- `api_base_url`
- `workspace_dir`
- `workspace_game_dir`
- `workspace_artifacts_dir`
- `workspace_build_dir`
- `workspace_logs_dir`

**写入的 State 字段：**
- `software_name` - 检测到的本地软件工程名称

### 错误处理

| 错误场景 | 状态码 | 错误信息 |
|----------|--------|----------|
| 缺少凭证 | 400 | Missing required credentials: xxx |
| 远程项目获取失败 | - | remote_project_error 字段 |
| 远程版本获取失败 | - | remote_manifest_error 字段 |
| 本地工作空间不存在 | 404 | Workspace not fully ready. Missing: local_workspace |
| 本地软件工程不存在 | 404 | Workspace not fully ready. Missing: local_software |

### 实现注意事项

1. 使用 `_state_get()` 和 `_state_set()` 辅助函数进行 state 读写
2. 使用 `_ssl_context_for_url()` 创建 SSL 上下文
3. 使用 `_resp()` 函数构造返回结果
4. API 调用超时设置为 10 秒
5. 版本列表按时间倒序返回，第一个元素为最新版本
