# 启动 agent 测试系统流程

## 1. 启动 API Service

```bash
cd service
go run sparkx.go -f etc/sparkx-api-dev.yaml
```

- 服务地址（dev 配置默认）：https://localhost:8890

## 2. 启动 Web Admin

```bash
cd web_admin
npm run dev -- --host 0.0.0.0 --port 5173
```

- 访问地址：http://localhost:5173/

## 3. 启动 Agent Service（service_ws）

```bash
cd agents
# 启动虚拟环境（如需）
# Windows PowerShell 示例：
# .\.venv\Scripts\Activate.ps1

python -m service.service_ws
```

- 服务地址：http://127.0.0.1:8001

## 4. 启动 Agent Web

```bash
cd agents
# 启动虚拟环境（如需）
# Windows PowerShell 示例：
# .\.venv\Scripts\Activate.ps1

cd web
'npm run dev'
```

- 访问地址：http://127.0.0.1:8002/
