# SparkPlay

## 平台愿景

释放每一份创意，让游戏创作归于简单

## 平台能力

- 项目管理：创建/打开项目，管理版本与构建产物
- 资源管理：统一管理文本、图片、音频、视频等资源及其版本
- 工程协作：面向工程结构的可视化编辑与迭代
- Agent 辅助：结合智能体与模型能力，辅助代码与资产生成
- 游戏发布与预览：一键构建发布包，并支持平台预览验证（Web/移动端）

## 项目文件结构

```text
SparkPlay/
├── .github/                 # CI/CD（GitHub Actions）
├── design/                  # 平台设计文档与数据表拆分索引
├── deploy/                  # 部署配置（docker-compose）
├── agents/                  # 智能体相关实现与模板
├── web/                     # Web 前端（编辑器/工作台）
├── service/                 # 后端服务（如有）
└── skills/                  # 可复用技能定义
```

项目数据表设计索引：`design/SparkX_Table_Design.md`

## .github（CI/CD）

当前仓库包含一个 GitHub Actions 工作流：`.github/workflows/aliyun-acr-build-deploy.yml`，用于：

- 在 `main/master` 分支 push 时构建 Docker 镜像并推送到阿里云 ACR
- 在构建完成后，通过 SSH 将 `deploy/docker-compose.yml` 分发到服务器并执行 `docker compose pull/up`

工作流要点：

- 仓库包含 git submodules，工作流会 `checkout` 并递归拉取 submodules
- 仅对存在 `Dockerfile` 的组件执行构建（当前仅 `web/` 有 `Dockerfile`，`agents/` 与 `service/` 会自动跳过）
- 会将 `postgres:15.13-alpine` 镜像同步到 ACR，供部署时使用

需要配置的 Secrets（Settings → Secrets and variables → Actions）：

- `GH_SUBMODULES_SSH_PRIVATE_KEY`：用于拉取私有 submodule 的 SSH 私钥
- `ALIYUN_ACR_REGISTRY` / `ALIYUN_ACR_NAMESPACE` / `ALIYUN_ACR_USERNAME` / `ALIYUN_ACR_PASSWORD`：ACR 登录信息
- `ALIYUN_DEPLOY_SSH_PRIVATE_KEY`：用于登录部署服务器的 SSH 私钥
- `ALIYUN_DEPLOY_HOST` / `ALIYUN_DEPLOY_USER`：部署服务器地址与用户
- `ALIYUN_DEPLOY_DIR`：远端部署目录（可选，默认 `sparkx`）

## deploy（部署）

`deploy/docker-compose.yml` 当前包含：

- `web`：`ACR_REGISTRY/ACR_NAMESPACE/sparkplay-web:${WEB_TAG:-latest}`，默认映射 `80 -> 3000`
- `postgres`：默认 `postgres:15.13-alpine`，也支持通过 `POSTGRES_IMAGE` 指定 ACR 内镜像

常用环境变量：

- `ACR_REGISTRY`、`ACR_NAMESPACE`：镜像仓库地址与命名空间（使用私有 ACR 时必填）
- `WEB_TAG`、`WEB_PORT`：Web 镜像 tag 与对外端口
- `POSTGRES_IMAGE`、`POSTGRES_DB`、`POSTGRES_USER`、`POSTGRES_PASSWORD`、`POSTGRES_PORT`

在服务器上手动部署/更新（示例）：

```bash
cd /path/to/deploy-dir
docker compose -f docker-compose.yml pull
docker compose -f docker-compose.yml up -d --remove-orphans
```
