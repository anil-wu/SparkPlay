## 1. 启动 API Service

```bash
cd service
go run sparkx.go -f etc/sparkx-api-dev.yaml
```

- 服务地址（dev 配置默认）：https://localhost:8890


## 2. 启动 SparkX Web

```bash
cd web
npm run dev
```

- 访问地址：http://localhost:3000/
- 说明：Next.js 开发服务器默认端口为 3000

## 3 启动 Web Admin

```bash
cd web_admin
npm run dev -- --host 0.0.0.0 --port 5173
```

- 访问地址：http://localhost:5173/


