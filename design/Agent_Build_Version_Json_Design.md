# Build Version JSON 设计方案

## 概述

本文档描述 `build_project_software` 工具的构建版本信息生成方案，包括构建产物的上传、`build_version.json` 的生成与存储。

## 整体流程

```
build_project_software 调用
    ↓
1. 运行 npm build 命令（在 workspace_game_dir/software_name）
    ↓
2. 扫描构建输出目录（workspace_game_dir/software_name/dist）
    ↓
3. 上传所有构建产物文件到文件系统
    ↓
4. 生成 build_version.json
    ↓
5. 上传 build_version.json 文件
    ↓
6. 调用 API: POST /api/v1/build-versions 创建数据库记录
    ↓
7. 返回构建结果 + build_version_id
```

## 目录结构

```
workspace_root/
├── {project_id}/
│   └── game/                          # workspace_game_dir
│       └── {software_name}/           # 源码目录
│           ├── src/
│           ├── dist/                  # 构建输出目录（扫描上传）
│           │   ├── index.html
│           │   ├── assets/
│           │   └── build_version.json
│           └── package.json
```

## build_version.json 结构

```json
{
  "softwareName": "my-game",
  "version": "1.0.0",
  "versionCode": 1,
  "versionDescription": "首次构建发布版本",
  "buildCommand": "run build",
  "buildTime": "2026-02-17T10:30:00Z",
  "entry": "index.html",
  "files": [
    {
      "path": "index.html",
      "fileId": 123,
      "versionId": 456,
      "versionNumber": 1,
      "hash": "abc123...",
      "size": 1024,
      "lastModified": "2026-02-17T10:30:00Z"
    },
    {
      "path": "assets/bundle.js",
      "fileId": 124,
      "versionId": 457,
      "versionNumber": 1,
      "hash": "def456...",
      "size": 51200,
      "lastModified": "2026-02-17T10:30:00Z"
    }
  ],
  "folders": ["assets", "images"],
  "totalFiles": 15,
  "totalSize": 1024000,
  "buildInfo": {
    "npmReturnCode": 0,
    "buildDurationMs": 5000
  }
}
```

## 字段说明

### 顶层字段

| 字段 | 类型 | 必填 | 说明 |
|-----|------|------|------|
| `softwareName` | string | 是 | 软件名称 |
| `version` | string | 是 | 版本号字符串，如 "1.0.0" |
| `versionCode` | int | 是 | 版本代码，整数递增 |
| `versionDescription` | string | 否 | 版本描述 |
| `buildCommand` | string | 是 | 构建命令 |
| `buildTime` | string | 是 | 构建时间（ISO 8601 格式） |
| `entry` | string | 是 | 入口文件路径 |
| `files` | array | 是 | 构建产物文件列表 |
| `folders` | array | 是 | 文件夹列表 |
| `totalFiles` | int | 是 | 文件总数 |
| `totalSize` | int | 是 | 文件总大小（字节） |
| `buildInfo` | object | 是 | 构建信息 |

### files 数组元素字段

| 字段 | 类型 | 说明 |
|-----|------|------|
| `path` | string | 相对路径 |
| `fileId` | int | 文件 ID |
| `versionId` | int | 文件版本 ID |
| `versionNumber` | int | 版本号 |
| `hash` | string | 文件哈希值（SHA-256） |
| `size` | int | 文件大小（字节） |
| `lastModified` | string | 最后修改时间 |

### buildInfo 字段

| 字段 | 类型 | 说明 |
|-----|------|------|
| `npmReturnCode` | int | npm 命令返回码 |
| `buildDurationMs` | int | 构建耗时（毫秒） |

## 函数签名

### build_project_software

```python
def build_project_software(
    software_name: str,
    build_command: str = "run build",
    build_output_subdir: str = "dist",
    software_manifest_id: int | None = None,
    version: str | None = None,
    version_code: int | None = None,
    version_description: str | None = None,
    tool_context: Any = None,
) -> Dict[str, Any]:
```

### 参数说明

| 参数 | 类型 | 必填 | 说明 |
|-----|------|------|------|
| `software_name` | string | 是 | 软件名称 |
| `build_command` | string | 否 | npm 构建命令，默认 "run build" |
| `build_output_subdir` | string | 否 | 构建输出子目录，默认 "dist" |
| `software_manifest_id` | int | 否 | 软件 manifest ID |
| `version` | string | 否 | 版本号 |
| `version_code` | int | 否 | 版本代码 |
| `version_description` | string | 否 | 版本描述 |
| `tool_context` | Any | 是 | 工具上下文 |

## 数据库字段对应

| build_version.json 字段 | build_versions 表字段 |
|------------------------|----------------------|
| - | `project_id` |
| - | `software_manifest_id` |
| `versionDescription` | `description` |
| build_version.json 文件 | `build_version_file_id` |
| build_version.json 版本 | `build_version_file_version_id` |

## 需要修改的文件

### 1. work_space_manager.py

**修改函数**: `build_project_software`
- 新增参数: `software_manifest_id`, `version`, `version_code`, `version_description`
- 复制构建产物到 `workspace_build_dir/software_name` 后
- 扫描该目录并上传所有文件
- 生成并上传 build_version.json
- 调用 create_build_version API

### 2. project.py

**新增函数**: `create_build_version`
- 调用 API: POST /api/v1/build-versions
- 创建 build_versions 表记录

### 3. build_agent.py

- 更新 instruction 说明新参数用法

## API 接口

### POST /api/v1/build-versions

**请求体**:
```json
{
  "projectId": 1,
  "softwareManifestId": 1,
  "description": "首次构建发布版本",
  "buildVersionFileId": 123,
  "buildVersionFileVersionId": 456
}
```

**响应体**:
```json
{
  "buildVersionId": 1,
  "projectId": 1,
  "softwareManifestId": 1,
  "description": "首次构建发布版本",
  "buildVersionFileId": 123,
  "buildVersionFileVersionId": 456,
  "createdBy": 1,
  "createdAt": "2026-02-17T10:30:00Z"
}
```

## 参考文档

- [SparkX_Table_Design.05_Build_System.md](./SparkX_Table_Design.05_Build_System.md) - 构建系统表设计
- [Agent_Design.md](./Agent_Design.md) - Agent 架构设计
