# Web 构建产物上传与预览执行方案（最终）

## 目标

在 OpenCode 沙盒内完成 Web 游戏开发并构建得到静态产物目录（如 `build/` 或 `dist/`），将该目录按原目录结构上传到文件系统（对象存储），Web 端只需通过构建版本 ID 即可预览并正常游玩。

预览唯一入口：

- `GET /api/v1/previews/builds/{buildVersionId}/`

并支持资源自动加载：

- `GET /api/v1/previews/builds/{buildVersionId}/{path...}`

## 核心原则

- 预览的“资源路径解析”交给浏览器天然机制：入口 HTML 通过 `<base href>` 统一资源前缀，避免额外的运行时路径重写与清单查询。
- 上传侧必须严格使用 preupload 接口返回的 `contentType` 进行 PUT 直传，确保签名一致与浏览器 MIME 校验通过。
- 预览侧尽量使用 302 跳转到对象存储的短期签名 GET URL，避免 service 代理大文件造成带宽与性能压力。

## 一、数据模型与存储 Key 规范

### 1.1 构建产物对象存储 Key（强约束）

构建产物根目录（以下称 build root）下的每个文件，上传到对象存储的固定前缀目录：

- `previews/{projectId}/{softwareManifestId}/{buildVersionId}/{relativePath}`

其中：

- `relativePath` 为 build root 内相对路径（统一使用 `/`，去除前导 `./`、`/`）。
- 示例：
  - `previews/12/3/101/index.html`
  - `previews/12/3/101/assets/index-xxxx.js`
  - `previews/12/3/101/assets/index-xxxx.css`

### 1.2 build_versions 表新增字段（执行必做）

在 `build_versions` 表新增：

- `preview_storage_prefix`（varchar）
  - 值：`previews/{projectId}/{softwareManifestId}/{buildVersionId}/`

可选（非必做）：

- `entry_path`（varchar，默认 `index.html`）

说明：

- `preview_storage_prefix` 是预览路由定位资源的唯一权威指针，预览不再依赖 `build_version.json` 的 files 映射做运行时查询。

## 二、Service 侧：预览路由（必须实现）

### 2.1 入口页

路由：

- `GET /api/v1/previews/builds/{buildVersionId}/`

处理逻辑：

1. 鉴权：校验请求用户对该 `buildVersionId` 所属 `projectId` 有访问权限。
2. 查询 `build_versions` 获取：
   - `projectId`
   - `softwareManifestId`（即 `build_versions.software_manifest_id`）
   - `preview_storage_prefix`
   - `entry_path`（若未存表则默认为 `index.html`）
3. 读取入口文件内容：
   - `storageKey = preview_storage_prefix + entry_path`
4. 返回 HTML，并注入：
   - `<base href="/api/v1/previews/builds/{buildVersionId}/">`
5. 返回头建议：
   - `Content-Type: text/html; charset=utf-8`
   - `Cache-Control: no-store`

注入 `<base>` 的目的：

- 保证 `./assets/...`、动态导入 chunk、CSS `url(...)` 等相对路径统一落到 `/api/v1/previews/builds/{buildVersionId}/` 之下，由同一套资源路由服务。

### 2.2 资源

路由（推荐，避免通配符路由在部分框架下不命中）：

- `GET /api/v1/previews/builds/{buildVersionId}/asset?path={relativePath}`

兼容路由（可保留，但不作为主路径依赖）：

- `GET /api/v1/previews/builds/{buildVersionId}/{path...}`

处理逻辑：

1. 鉴权同入口页。
2. 获取 `preview_storage_prefix`。
3. 计算资源路径：
   - `requestedPath = normalize(relativePath)`
   - `storageKey = preview_storage_prefix + requestedPath`
4. 获取该 `storageKey` 的对象存储短期签名 GET URL。
5. 返回 `302` 重定向到签名 URL（推荐）：
   - `Location: {signedGetUrl}`
   - `Cache-Control: no-store`

可选（仅在必要时）：

- 对 `text/css` 等进行代理与重写，但在注入 `<base>` 后通常不需要。

## 三、上传侧（OpenCode）：执行顺序与接口（必须调整）

上传逻辑参考现有实现：

- [sparkx_upload_build.ts](file:///e:/研究/AIGame/SparkPlay/opencode/.opencode/tools/sparkx_upload_build.ts)

### 3.1 执行顺序（推荐采用）

为了让对象存储路径包含 `{buildVersionId}` 并与预览入口严格一致，上传流程必须保证在上传产物前可拿到 `buildVersionId`。

推荐顺序：

1. 创建 buildVersion draft 拿到 `buildVersionId`
2. 按 `previews/{projectId}/{softwareManifestId}/{buildVersionId}/` 上传 build root 内所有文件
3. （可选）生成并上传 `build_version.json` 作为构建 manifest（元数据）
4. 更新 buildVersion（写入 `preview_storage_prefix`、`entry_path`，以及 `build_version.json` 的 file/version 指针）

说明：

- 如果现有 `POST /api/v1/build-versions` 必须要求 `buildVersionFileId/buildVersionFileVersionId`，则需要新增一个“draft buildVersion”接口，或允许先创建记录再补全（当前实现采用 draft + PUT 更新）。

### 3.2 preupload 必须支持写入目标 storageKey

当前上传脚本对每个文件调用：

- `POST /api/v1/files/preupload`，body 含 `projectId, name(relativePath), fileCategory, fileFormat, sizeBytes, hash`

执行方案要求 service 在生成上传 URL 时，能够把 `relativePath` 放到 `previews/.../{buildVersionId}/` 目录下。

可选实现方式（二选一）：

1. 新增接口（推荐）：
   - `POST /api/v1/previews/builds/{buildVersionId}/preupload`
   - 由 service 内部使用 `previews/{projectId}/{softwareManifestId}/{buildVersionId}/{relativePath}` 生成 storageKey 并签名 PUT
2. 扩展现有 `/files/preupload`：
   - 增加 `storagePrefix`（例如 `previews/.../{buildVersionId}/`）与 `relativePath`

无论使用哪种方式：

- PUT 上传必须使用 preupload 返回的 `contentType`（现脚本已正确使用）。

## 四、Web 侧：预览播放（必须简化）

Web 侧仅需：

- iframe 直接指向 service：
  - `/api/v1/previews/builds/{buildVersionId}/`

说明：

- 在 Next.js 下建议通过同域 API 代理（`/api/v1/previews/...`）转发到 service，以便复用登录态（session cookie）与鉴权头，并透传 302 跳转。

Web 不再需要：

- 通过下载 `build_version.json` 来解析入口与资源映射
- 自己实现 Next 路由层的 “build_version.json -> files 映射 -> 再下载资源”

## 五、兼容与回滚策略

为了平滑迁移，可在 service 预览路由中加入兼容逻辑：

- 若 `preview_storage_prefix` 为空：
  - 回退到旧机制：读取 `build_version.json`，按 `files[].path -> fileId/versionId` 映射资源（建议加内存缓存）
- 若 `preview_storage_prefix` 存在：
  - 走目录版本（prefix）机制（推荐路径）

回滚方式：

- 保持原 Web 侧 Next 预览路由不删除，必要时切回原 iframe 地址即可。

## 六、验收标准

- 给定 `buildVersionId`，访问 `/api/v1/previews/builds/{buildVersionId}/` 能返回入口 HTML。
- 入口 HTML 加载的相对资源（`./assets/*`、动态 chunk、CSS url()）均能成功加载。
- 浏览器控制台无 “Strict MIME type checking” 导致的模块脚本拒绝执行错误。
- service 侧 QPS 与延迟不随资源数量线性恶化（资源请求以 302 到对象存储为主）。

