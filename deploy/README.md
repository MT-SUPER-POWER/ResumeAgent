# Deploy — ResumeAgent Kubernetes 部署

## 目录结构

```
deploy/
├── scripts/
│   ├── deploy.sh          # 统一管理脚本 (Linux/macOS)
│   └── deploy.ps1         # 统一管理脚本 (Windows PowerShell)
├── namespace.yaml          # 命名空间: resume-agent
├── secret.yaml             # PostgreSQL 凭证 + 连接串
├── pod/
│   ├── postgres-pvc.yaml           # 持久化存储 (10Gi)
│   └── postgres-statefulset.yaml   # PostgreSQL 16 Alpine
└── svc/
    └── postgres-service.yaml       # LoadBalancer Service (localhost:30432)
```

## 快速开始

```bash
# 部署 PostgreSQL
./deploy/scripts/deploy.sh pg up

# 查看状态
./deploy/scripts/deploy.sh pg status

# 获取连接信息
./deploy/scripts/deploy.sh pg connect

# 一键进入 psql
./deploy/scripts/deploy.sh pg psql

# 卸载
./deploy/scripts/deploy.sh pg down
```

Windows PowerShell：

```powershell
.\deploy\scripts\deploy.ps1 pg up
.\deploy\scripts\deploy.ps1 pg status
.\deploy\scripts\deploy.ps1 pg connect
```

## 连接 PostgreSQL

| 方式                 | 命令                                                                             |
| -------------------- | -------------------------------------------------------------------------------- |
| LoadBalancer (宿主机直连) | `psql -h 127.0.0.1 -p 30432 -U resume_agent -d resume_agent`                 |
| GUI 数据库工具       | `Host=127.0.0.1 Port=30432 User=resume_agent Database=resume_agent`              |
| Cluster DNS (集群内) | `postgresql://resume_agent:<pwd>@resume-agent-pg.resume-agent:5432/resume_agent` |

> 当前配置面向 Docker Desktop Kubernetes：`LoadBalancer` 会把 PostgreSQL 长期暴露到宿主机 `127.0.0.1:30432`，同时保留集群内 `resume-agent-pg:5432`。

## 常用命令

| 命令         | 用途                              |
| ------------ | --------------------------------- |
| `pg up`      | 部署 PostgreSQL                   |
| `pg down`    | 卸载 PostgreSQL（保留 Namespace） |
| `pg status`  | 查看 Pod / Service / PVC 状态     |
| `pg connect` | 打印连接字符串                    |
| `pg psql`    | 通过本地 LoadBalancer 进入 psql   |
| `help`       | 显示帮助信息                      |
