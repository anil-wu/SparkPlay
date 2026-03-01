# 工程版本的 Git 管理方案（最终版）

## 1. 目标

- 工程源码用 **Gitea/Git** 做版本管理（协作、Tag、回滚；不使用分支）。
- 构建不走 CI/CD，在 **OpenCode 同环境**“开发完立即构建+预览”。
- 构建产物（Web 静态资源）上传到 **对象存储（OSS）**，由 **SparkX Service** 提供预签名上传通道与版本记录。
- 发布（Release）仅做“选择某个构建版本为当前发布版本”。

## 2. 职责分工

- **Gitea（源码仓库）**：代码版本 = commit/tag。
- **OpenCode（Build Runner）**：拉取/切换 tag/commit、执行 `npm build`、上传 `dist/`、生成 `build_version.json`、调用 service 入库。
- **SparkX Service（版本与存储网关）**：
  - `POST /api/v1/files/preupload`：生成 OSS `PUT` 预签名 URL，并写入文件版本（实现见 [preuploadfilelogic.go](file:///e:/%E7%A0%94%E7%A9%B6/AIGame/SparkPlay/service/internal/logic/files/preuploadfilelogic.go#L161-L291)）。
  - `POST /api/v1/software-manifests`：创建工程版本记录（实现见 [createsoftwaremanifestlogic.go](file:///e:/%E7%A0%94%E7%A9%B6/AIGame/SparkPlay/service/internal/logic/softwares/createsoftwaremanifestlogic.go#L35-L127)）。
  - `POST /api/v1/build-versions`：创建构建版本记录（实现见 [createbuildversionlogic.go](file:///e:/%E7%A0%94%E7%A9%B6/AIGame/SparkPlay/service/internal/logic/builds/createbuildversionlogic.go#L31-L122)）。
  - `POST /api/v1/releases`：选择 build_version 作为发布版本（接口见 [sparkx.api](file:///e:/%E7%A0%94%E7%A9%B6/AIGame/SparkPlay/service/sparkx.api#L777-L791)）。

## 3. 数据与版本关系（必须）

- **software_manifest 必留**：作为“平台侧工程版本实体”，否则 `build_versions` 无法创建（现实现强依赖 `softwareManifestId`，见 [createbuildversionlogic.go](file:///e:/%E7%A0%94%E7%A9%B6/AIGame/SparkPlay/service/internal/logic/builds/createbuildversionlogic.go#L38-L64)）。
- **software_manifest 最小化内容**：不再存“源码文件列表”，只存“构建输入锚点”。
  - `manifest_file_id/manifest_file_version_id` 指向一个小 JSON（建议命名 `software.manifest.json`），至少包含：`repo`、`gitRef`、`commitSha`、`buildCommand`、`outputDir`。

## 4. 构建流程（OpenCode 同环境即时构建）

输入：`projectId`、`softwareId`、`gitRef`（tag/commitSha；不使用分支）、`buildCommand`（默认 `npm run build`）、`outputDir`（默认 `dist`）、`description`。

步骤：

1. `git checkout gitRef`（tag 或 commitSha），得到 `commitSha`。
2. 运行构建：`npm ci` → `npm run build`。
3. 生成并上传 `software.manifest.json`：
   - `POST /api/v1/files/preupload` → `PUT uploadUrl` 上传 JSON
   - `POST /api/v1/software-manifests` 创建工程版本，拿到 `softwareManifestId`
4. 上传 `dist/**` 每个文件：
   - 目标：**按 dist 目录结构上传到 OSS**
   - OSS Key 约定：`previews/{projectId}/{softwareId}/{buildVersionKey}/{relativePath}`
   - 对每个文件：`POST /api/v1/files/preupload` → `PUT uploadUrl`
5. 生成并上传 `build_version.json`（包含 commitSha + dist 文件清单及每个文件的 `fileId/versionId`）：
   - `POST /api/v1/files/preupload` → `PUT uploadUrl`
6. 入库构建版本：`POST /api/v1/build-versions`（service 自动递增 `version_number`，见 [createbuildversionlogic.go](file:///e:/%E7%A0%94%E7%A9%B6/AIGame/SparkPlay/service/internal/logic/builds/createbuildversionlogic.go#L73-L88)）。

## 5. 发布流程（Release=选择构建版本）

- 选择某个 `build_version_id` 作为指定 `channel/platform` 的发布版本：`POST /api/v1/releases`（接口见 [sparkx.api](file:///e:/%E7%A0%94%E7%A9%B6/AIGame/SparkPlay/service/sparkx.api#L777-L791)）。
- 回滚=再选一个更旧的 `build_version_id`。

## 6. 预览（即时查看）

预览不在沙箱内起静态服务，而是：

1. 构建后将 `dist/` **按目录结构**上传到 OSS（见上文 Key 约定）。
2. Web 侧通过 **api-service 的预览路由**访问指定构建版本的入口文件与静态资源。

建议预览路由形态（api-service 提供）：

- 入口页：`GET /api/v1/previews/builds/{buildVersionId}/` → 返回该构建版本的 `index.html`
- 资源：`GET /api/v1/previews/builds/{buildVersionId}/{path...}` → 返回该构建版本对应的静态资源

服务端实现要点（行为定义）：

- api-service 根据 `buildVersionId` 定位该构建版本对应的 `build_version.json`（或直接用 OSS Key 规则定位文件）。
- 对 `index.html` 与资源请求：
  - 优先返回 **302 重定向到 OSS 的临时 GET URL**（复用已有签名下载能力的思路，见 [downloadfilelogic.go](file:///e:/%E7%A0%94%E7%A9%B6/AIGame/SparkPlay/service/internal/logic/files/downloadfilelogic.go#L100-L116)）。
  - 或直接代理返回内容（类似 [getfilecontentlogic.go](file:///e:/%E7%A0%94%E7%A9%B6/AIGame/SparkPlay/service/internal/logic/files/getfilecontentlogic.go#L33-L97)）。

## 7. 安全约束

- OpenCode 环境**不保存** OSS AK/SK；只使用 `/files/preupload` 的预签名 URL 上传。
- Git 拉取使用 deploy key/最小权限 token；Gitea 管理权限仅在 service 侧。

