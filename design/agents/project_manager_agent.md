# Project Manager Agent 设计文档

> **状态**: 设计中
> **实现文件**: `agents/phaser_agent/agents/project_manager_agent.py`

## 一、Agent 定义

| 属性 | 值 |
|------|-----|
| **名称** | `project_manager_agent` |
| **角色** | 项目生命周期管理专家 |
| **职责** | 项目创建、工作空间管理、版本同步（拉取/推送） |

## 二、工具列表

| 序号 | 工具名称 | 功能描述 |
|------|----------|----------|
| 1 | `get_project_info` | 获取项目信息及软件工程列表 |
| 2 | `create_project` | 创建新项目并初始化工作空间 |
| 3 | `get_local_project_info` | 获得本地项目工程信息 |
| 4 | `init_project_workspace` | 初始化项目工程 |
| 5 | `pull_project` | 拉取项目工程 |
| 6 | `push_project` | 推送项目工程 |

## 三、工具详细设计

### 3.1 `get_project_info` - 获取项目信息

**功能**: 获取项目详细信息及其关联的软件工程列表

**执行流程**:
```
1. 检查 state 中的 project_id（必需）
2. 调用 GET /api/v1/projects/{project_id} 获取项目信息
3. 调用 GET /api/v1/projects/{project_id}/softwares 获取软件工程列表
4. 合并返回完整信息
```

**API 调用**:

| 步骤 | API | 说明 |
|------|-----|------|
| 1 | `GET /api/v1/projects/{project_id}` | 获取项目基本信息 |
| 2 | `GET /api/v1/projects/{project_id}/softwares` | 获取软件工程列表 |

**返回数据结构**:
```json
{
  "status": "success",
  "status_code": 200,
  "message": "获取项目信息成功",
  "data": {
    "project": {
      "id": 123,
      "name": "My Phaser Game",
      "description": "A platformer game project",
      "coverFileId": 456,
      "ownerId": 1001,
      "status": "active",
      "createdAt": "2026-01-15T10:00:00Z",
      "updatedAt": "2026-02-10T15:30:00Z"
    },
    "softwares": [
      {
        "id": 1,
        "projectId": 123,
        "name": "main-game",
        "description": "主游戏工程",
        "templateId": 1,
        "technologyStack": "phaser",
        "status": "active",
        "createdBy": 1001,
        "createdAt": "2026-01-15T10:05:00Z",
        "updatedAt": "2026-02-18T09:00:00Z"
      }
    ],
    "software_count": 1
  }
}
```

**错误情况**:

| 场景 | status_code | message |
|------|-------------|---------|
| project_id 未设置 | 400 | "project_id is required" |
| 项目不存在 | 404 | "项目不存在" |
| 无权限访问 | 403 | "无权限访问该项目" |
| API 请求失败 | 500 | "请求失败: {error}" |

---

### 3.2 `create_project` - 创建新项目

**功能**: 在后端创建新项目记录，并初始化本地工作空间

**参数**:

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `project_name` | string | 是 | 项目名称 |
| `description` | string | 否 | 项目描述 |

**执行流程**:
```
1. 调用 POST /api/v1/projects 创建项目记录
2. 获取返回的 project_id，写入 state
3. 创建本地工作空间目录结构：
   {workspace_root}/{user_id}/{project_id}/
   ├── game_project/
   ├── artifacts/
   ├── build/
   └── logs/
4. 更新 state 中的 workspace_dir 等路径
```

**API 调用**:

| 步骤 | API | 说明 |
|------|-----|------|
| 1 | `POST /api/v1/projects` | 创建项目记录 |

**请求体**:
```json
{
  "userId": 1001,
  "name": "My New Project",
  "description": "Project description"
}
```

**返回数据结构**:
```json
{
  "status": "success",
  "status_code": 200,
  "message": "项目创建成功",
  "data": {
    "project_id": 124,
    "project": {
      "id": 124,
      "name": "My New Project",
      "description": "Project description",
      "ownerId": 1001,
      "status": "active"
    },
    "workspace": {
      "workspace_dir": "workspaces/1001/124",
      "workspace_game_dir": "workspaces/1001/124/game_project",
      "workspace_artifacts_dir": "workspaces/1001/124/artifacts",
      "workspace_build_dir": "workspaces/1001/124/build",
      "workspace_logs_dir": "workspaces/1001/124/logs"
    }
  }
}
```

---

### 3.3 `get_local_project_info` - 获得本地项目工程信息

**功能**: 扫描本地工作空间，获取软件工程列表和 manifest 信息

**执行流程**:
```
1. 检查 workspace_dir 是否存在
2. 扫描 workspace_game_dir 下的子目录
3. 对每个软件工程：
   - 检查是否存在 manifest.json
   - 读取并解析 manifest 内容
4. 返回本地工程概览
```

**返回数据结构**:
```json
{
  "status": "success",
  "status_code": 200,
  "message": "获取本地工程信息成功",
  "data": {
    "workspace_dir": "workspaces/1001/124",
    "workspace_exists": true,
    "software_projects": [
      {
        "name": "my-game",
        "path": "workspaces/1001/124/game_project/my-game",
        "has_manifest": true,
        "manifest": {
          "engine": {
            "name": "phaser",
            "version": "3.60.0"
          },
          "entry": "src/main.ts",
          "files_count": 25,
          "folders": ["src", "assets"]
        }
      }
    ],
    "software_count": 1
  }
}
```

**错误情况**:

| 场景 | status_code | message |
|------|-------------|---------|
| workspace_dir 未设置 | 400 | "workspace_dir is required" |
| 工作空间不存在 | 404 | "工作空间不存在" |

---

### 3.4 `init_project_workspace` - 初始化项目工程

**功能**: 使用模板初始化软件工程目录

**参数**:

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `software_name` | string | 是 | 软件工程名称 |
| `template_name` | string | 否 | 模板名称（默认使用 "phaser-blank"） |

**执行流程**:
```
1. 检查 workspace_game_dir 是否存在
2. 创建 {workspace_game_dir}/{software_name} 目录
3. 根据模板名称查询模板信息：
   GET /api/v1/templates?name={template_name}
4. 从后端下载模板归档：
   GET /api/v1/templates/{template_id}/download
5. 解压到目标目录
6. 生成初始 manifest.json
```

**返回数据结构**:
```json
{
  "status": "success",
  "status_code": 200,
  "message": "工程初始化成功",
  "data": {
    "software_name": "my-game",
    "software_dir": "workspaces/1001/124/game_project/my-game",
    "template_name": "phaser-blank",
    "files_created": 12,
    "manifest": {
      "engine": {"name": "phaser", "version": "3.60.0"},
      "entry": "src/main.ts",
      "files": [],
      "folders": ["src", "assets"]
    }
  }
}
```

**错误情况**:

| 场景 | status_code | message |
|------|-------------|---------|
| software_name 为空 | 400 | "software_name is required" |
| 工程目录已存在 | 409 | "软件工程已存在: {software_name}" |
| 模板不存在 | 404 | "模板不存在: {template_name}" |

---

### 3.5 `pull_project` - 拉取项目工程

**功能**: 从后端拉取最新版本的工程文件

**参数**:

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `software_name` | string | 是 | 软件工程名称 |
| `version_number` | int | 否 | 指定版本号（默认最新） |

**执行流程**:
```
1. 获取软件工程信息：
   GET /api/v1/projects/{project_id}/softwares
2. 获取最新 manifest 文件版本：
   GET /api/v1/projects/{project_id}/software_manifests?software_ids={software_id}
3. 下载 manifest 内容：
   GET /api/v1/files/{manifest_file_id}/content
4. 对比本地文件，下载变更/缺失的文件
5. 更新本地 manifest.json
```

**API 调用**:

| 步骤 | API | 说明 |
|------|-----|------|
| 1 | `GET /api/v1/projects/{project_id}/softwares` | 获取软件工程列表 |
| 2 | `GET /api/v1/projects/{project_id}/software_manifests?software_ids={id}` | 获取最新 manifest 信息 |
| 3 | `GET /api/v1/files/{file_id}/content` | 下载 manifest 内容 |
| 4 | `GET /api/v1/files/{file_id}/versions` | 获取文件版本列表 |
| 5 | `GET /api/v1/files/{file_id}/content` | 下载文件内容 |

**返回数据结构**:
```json
{
  "status": "success",
  "status_code": 200,
  "message": "拉取成功",
  "data": {
    "software_name": "my-game",
    "pulled_version": 5,
    "files_updated": 8,
    "files_added": 2,
    "files_unchanged": 15,
    "files_deleted": 0,
    "manifest_updated": true
  }
}
```

**错误情况**:

| 场景 | status_code | message |
|------|-------------|---------|
| software_name 为空 | 400 | "software_name is required" |
| 软件工程不存在 | 404 | "软件工程不存在: {software_name}" |
| 无版本记录 | 404 | "远程无版本记录" |

---

### 3.6 `push_project` - 推送项目工程

**功能**: 将本地变更推送到后端，创建新版本

**参数**:

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `software_name` | string | 是 | 软件工程名称 |
| `version_description` | string | 否 | 版本描述 |

**执行流程**:
```
1. 扫描本地软件目录，计算文件哈希
2. 获取远程 manifest，对比检测变更
3. 对变更文件：
   a. 调用 POST /api/v1/files/pre-upload 获取上传 URL
   b. 上传文件到 OSS
   c. 确认上传完成
4. 更新 manifest.json 并上传
5. 调用 POST /api/v1/software-manifests 创建版本记录
```

**API 调用**:

| 步骤 | API | 说明 |
|------|-----|------|
| 1 | `GET /api/v1/projects/{project_id}/softwares` | 获取软件工程列表 |
| 2 | `GET /api/v1/projects/{project_id}/software_manifests` | 获取最新 manifest 信息 |
| 3 | `POST /api/v1/files/pre-upload` | 获取文件上传 URL |
| 4 | `PUT {upload_url}` | 上传文件到 OSS |
| 5 | `POST /api/v1/software-manifests` | 创建 manifest 版本记录 |

**返回数据结构**:
```json
{
  "status": "success",
  "status_code": 200,
  "message": "推送成功",
  "data": {
    "software_name": "my-game",
    "new_version": 6,
    "files_uploaded": 3,
    "files_modified": 2,
    "files_added": 1,
    "files_unchanged": 18,
    "manifest_id": 456,
    "version_number": 6
  }
}
```

**错误情况**:

| 场景 | status_code | message |
|------|-------------|---------|
| software_name 为空 | 400 | "software_name is required" |
| 本地工程不存在 | 404 | "本地工程不存在: {software_name}" |
| 无变更 | 400 | "无变更需要推送" |

## 四、Agent Instruction

```
你是一个项目管理专家，负责管理项目的完整生命周期。

## 核心职责
1. 项目创建与信息管理
2. 本地工作空间维护
3. 工程版本同步（拉取/推送）

## 前置检查

在执行任何操作前，首先检查 state 中的 project_id：
- 如果 project_id 存在且有效：当前已有项目，可执行查看、同步等操作
- 如果 project_id 不存在或为空：当前无项目，需要先创建项目

## 工作流程

### 场景一：当前无项目（project_id 为空）
1. 调用 create_project 创建项目记录和工作空间
2. 调用 init_project_workspace 初始化软件工程

### 场景二：当前已有项目（project_id 存在）

#### 查看项目状态
1. 调用 get_project_info 获取远程项目信息和软件工程列表
2. 调用 get_local_project_info 获取本地工程状态

#### 同步工程
- 拉取：调用 pull_project 下载最新版本
- 推送：调用 push_project 上传本地变更

#### 初始化新工程
- 调用 init_project_workspace 在现有项目下创建新的软件工程

## 注意事项
- 创建项目前必须确认 project_id 为空，避免重复创建
- 推送前确保本地有实际变更
- 拉取前检查本地是否有未提交的变更，避免覆盖
- 始终保持 state 中的 project_id 和 workspace_dir 同步
```

## 五、架构整合

```
phaser_agent (根 Agent)
├── project_manager_agent
│   ├── get_project_info
│   ├── create_project
│   ├── get_local_project_info
│   ├── init_project_workspace
│   ├── pull_project
│   └── push_project
├── coder_agent
├── debugger_agent
├── verifier_agent
└── build_agent
```

## 六、State 依赖

工具执行依赖以下 state 字段：

| 字段 | 来源 | 说明 |
|------|------|------|
| `token` | 服务启动注入 | JWT 认证令牌 |
| `user_id` | 服务启动注入 | 用户 ID |
| `project_id` | 服务启动注入 / create_project 写入 | 项目 ID |
| `api_base_url` | 服务启动注入 | API 基础 URL |
| `workspace_dir` | create_project 写入 | 工作空间根目录 |
| `workspace_game_dir` | create_project 写入 | 游戏工程目录 |
| `workspace_artifacts_dir` | create_project 写入 | 资产目录 |
| `workspace_build_dir` | create_project 写入 | 构建输出目录 |
| `workspace_logs_dir` | create_project 写入 | 日志目录 |

## 七、实现计划

| 阶段 | 任务 | 文件 |
|------|------|------|
| **阶段 1** | 创建工具实现文件 | `agents/phaser_agent/tools/project_manager.py` |
| **阶段 2** | 创建 Agent 定义文件 | `agents/phaser_agent/agents/project_manager_agent.py` |
| **阶段 3** | 更新根 Agent 引用 | `agents/phaser_agent/agent.py` |
| **阶段 4** | 更新设计文档 | `design/Agent_Design.md` |
| **阶段 5** | 编写单元测试 | `agents/tests/test_project_manager.py` |

## 八、参考文档

- [Agent_Design.md](../Agent_Design.md) - Agent 架构设计
- [SparkX_Table_Design.04_Software.md](../SparkX_Table_Design.04_Software.md) - 软件工程表设计
- [workspace_manager_agent_tools.md](./workspace_manager_agent_tools.md) - 现有工具设计参考
