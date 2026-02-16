# Agent 设计文档

本文档概述了 Agent 系统的当前设计，重点关注 `agent.py`、`work_space_manager_agent.py` 和 `coder_agent.py` 及其相关工具。

## 1. 概述

Agent 系统基于 `google.adk.agents.llm_agent` 框架构建，使用 `LiteLLM` 进行模型交互。系统采用分层结构，由根 Agent (`phaser_agent`) 将任务委派给专门的子 Agent。

## 2. Agent 架构

### 2.1. 根 Agent：`phaser_agent`
- **定义位置**：`agent.py`
- **角色**：作为主要入口点和编排者。它负责解析配置、初始化子 Agent 并委派任务。
- **子 Agent**：
  - `work_space_manager_agent`（条件性加载，基于配置）
  - `verifier_agent`
  - `coder_agent`
  - `debugger_agent`
  - *（已注释/保留：`spec_agent`、`planner_agent`）*
- **配置**：
  - 动态加载模型配置 (`_litellm_from_agent_config`) 和提示词模板 (`_prompt_value`)。
  - 支持针对特定模型提供商（如 DeepSeek）的应用补丁。

### 2.2. 工作区管理 Agent：`work_space_manager_agent`
- **定义位置**：`agents/work_space_manager_agent.py`
- **角色**：管理项目生命周期和工作区环境。它处理与后端 API 的交互，用于项目创建、更新和同步。
- **工具**：
  - `check_workspace_status`：检查工作区的当前状态。
  - `check_project_info`：从后端获取项目详情。
  - `create_project_info`：在后端创建新的项目条目。
  - `update_project_info`：更新现有项目元数据。
  - `create_project_workspace`：为项目设置本地目录结构。
  - `init_project_workspace`：使用特定的软件模板初始化工作区。
  - `pull_project_software`：从后端下载项目文件/软件。
  - `commit_project_software`：上传本地更改并在后端创建新的软件版本（提交）。

### 2.3. 编码 Agent：`coder_agent`
- **定义位置**：`agents/coder_agent.py`
- **角色**：负责读取、写入和修改代码文件，以及执行开发命令。
- **工具**：
  - **文件系统操作**：
    - `read_file`：读取文件内容（支持行范围）。
    - `write_file`：向文件写入内容。
    - `edit_file`：使用统一差异（unified diffs）或行范围替换来修改文件。
    - `list_files`：列出目录中的文件（支持 glob 模式）。
    - `search`：在文件中搜索文本或正则表达式模式。
    - `delete_file`：删除文件或目录。
    - `move_file`：移动或重命名文件/目录。
    - `ensure_dir`：如果目录不存在则创建目录。
  - **命令执行**：
    - `run_cmd`：执行 Shell 命令（目前通过 `run_npm` 限制为安全列表中的 NPM 命令）。

### 2.4. 调试 Agent：`debugger_agent`
- **定义位置**：`agents/debugger_agent.py`
- **角色**：专注于诊断和修复运行时错误。它负责分析代码、运行测试、查找错误源头并应用修复补丁。
- **工具**：
  - **文件系统操作**：
    - `read_file`：读取文件内容。
    - `write_file`：向文件写入内容。
    - `edit_file`：修改文件内容。
    - `list_files`：列出目录中的文件。
    - `search`：在文件中搜索文本（关键调试工具）。
  - **命令执行**：
    - `run_cmd`：执行 Shell 命令（`run_npm`），用于运行测试或启动开发服务器以复现问题。

### 2.5. 验证 Agent：`verifier_agent`
- **定义位置**：`agents/verifier_agent.py`
- **角色**：负责代码质量检查和功能验证。它执行测试套件、Lint 检查，并审查代码以确保符合项目标准。
- **工具**：
  - **文件系统操作**：
    - `read_file`：读取文件内容以审查代码或配置。
    - `list_files`：列出目录以查找测试文件或配置文件。
  - **命令执行**：
    - `run_cmd`：执行 Shell 命令（`run_npm`），用于运行测试 (`run test`) 或 Lint (`run lint`)。

## 3. 工具实现细节

工具在 `tools/` 目录下进行了模块化。

### 3.1. 工作区管理 (`tools/work_space_manager.py`)
- **后端交互**：使用 `urllib` 与 `SparkX` 后端 API 通信。
- **状态管理**：使用 `tool_context.state` 持久化会话信息，如 `user:token`、`user:project_id` 和 `user:workspace_game_dir`。
- **文件同步**：
  - `commit_project_software`：计算文件哈希以检测更改，将更改的文件上传到 OSS（对象存储），并更新软件清单（manifest）。
  - `init_project_workspace`：下载并解压模板归档以引导项目。

### 3.2. 文件系统 (`tools/filesystem.py`)
- **安全访问**：实现路径解析 (`_resolve_path`) 以防止路径遍历攻击，确保操作仅限于工作区内。
- **差异与打补丁**：包含一个健壮的补丁应用引擎 (`_apply_unified_diff` 和 `_fuzzy_block_replace`)，以弹性地处理代码编辑。
- **搜索**：实现了一个强大的搜索工具，支持正则表达式和资源限制（最大文件数/字符数）。

### 3.3. 命令执行 (`tools/commands.py`)
- **安全性**：`run_npm` 强制执行命令允许列表（`install`, `run build`, `run lint`, `run dev`, `run preview`），以防止任意代码执行。
- **输出处理**：捕获 `stdout` 和 `stderr`，为 Agent 提供错误摘要。

### 3.4. 清单 (`tools/manifest.py`)
- **项目结构**：`read_local_manifest` 允许 Agent 通过读取 `manifest.json` 文件来理解项目结构、入口点和资产。

## 4. 文件结构映射

- **`agent.py`**：主 Agent 组合与配置。
- **`agents/`**：
  - `work_space_manager_agent.py`：工作区任务的 Agent 定义。
  - `coder_agent.py`：编码任务的 Agent 定义。
  - `verifier_agent.py`：验证任务的 Agent 定义。
  - `debugger_agent.py`：调试任务的 Agent 定义。
- **`tools/`**：
  - `work_space_manager.py`：工作区工具的实现。
  - `filesystem.py`：文件 I/O 工具的实现。
  - `commands.py`：命令执行工具的实现。
  - `manifest.py`：清单读取工具的实现。

## 5. 数据流与工作区规范

### 5.1. 路径规范

系统采用层级化的目录结构，确保不同用户、不同项目的隔离性。

*   **项目工作空间根目录 (`workspace_dir`)**:
    *   规范: `{WORKSPACE_ROOT}/{user_id}/{project_id}`
    *   示例: `workspaces/1001/2002`
    *   说明: `WORKSPACE_ROOT` 默认为 `workspaces`，会被转换为绝对路径。
*   **软件工作目录 (`software_dir`)**:
    *   规范: `{workspace_dir}/game_project/{software_name}`
    *   示例: `workspaces/1001/2002/game_project/my_game`
    *   说明: `game_project` 为默认的 `DIR_GAME` 常量。
*   **其他子目录**:
    *   **构件目录**: `{workspace_dir}/artifacts`
    *   **构建输出**: `{workspace_dir}/build_output`
    *   **日志目录**: `{workspace_dir}/logs`

### 5.2. 关键信息的生命周期与注入

关键信息通过服务启动注入和工具执行生成两种方式写入 Agent 的 `tool_context.state`。

#### A. 服务启动阶段注入 (User/Project/Token/API Base)
由 WebSocket 服务 (`service_ws.py`) 在处理用户连接时获取并注入。

| 信息项 | 来源 | 写入位置 | 代码引用 |
| :--- | :--- | :--- | :--- |
| `user:token` | URL 参数或 Auth 消息 | `service_ws.py` | `state_seed["user:token"] = token` |
| `user:user_id` | Auth 消息 | `service_ws.py` | `state_seed["user:user_id"] = user_id` |
| `user:project_id`| Auth 消息 | `service_ws.py` | `state_seed["user:project_id"] = project_id` |
| `user:api_base_url` | 环境变量 `SPARKX_API_BASE_URL` | `service_ws.py` | `state_seed["user:api_base_url"] = api_base_url` |

> **注意**：`user:api_base_url` 指向后端服务 API 地址，默认通过环境变量配置（如 `SPARKX_API_BASE_URL`），在会话初始化时注入到状态中，供 `work_space_manager.py` 等工具使用以发起网络请求。

#### B. 工具执行阶段生成 (Workspace)
由 Agent 运行 `create_project_workspace` 工具时生成并写入。

| 信息项 | 生成逻辑 | 写入位置 |
| :--- | :--- | :--- |
| `user:workspace_dir` | `{root}/{uid}/{pid}` | `work_space_manager.py` |
| `user:workspace_game_dir` | `{workspace_dir}/game_project` | `work_space_manager.py` |
| `user:workspace_artifacts_dir` | `{workspace_dir}/artifacts` | `work_space_manager.py` |

#### C. 软件目录 (Software Name)
`software_name` **不写入全局 State**，而是作为参数传递给 `init_project_workspace` 或 `commit_project_software` 工具，由工具内部动态拼接路径使用。
