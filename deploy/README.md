# Deploy — ResumeAgent Kubernetes 部署

## 目录结构

```
deploy/
├── scripts/
│   ├── deploy.sh          # 统一管理脚本 (Linux/macOS)
│   └── deploy.ps1         # 统一管理脚本 (Windows PowerShell)
├── namespace.yaml          # 命名空间: resume-agent
├── secret.yaml             # PostgreSQL 凭证 + 连接串
├── backend/
│   ├── backend-secret.yaml         # 后端 application.local.yaml
│   ├── backend-serviceaccount.yaml # 后端 ServiceAccount
│   └── backend-deployment.yaml     # 后端 API Deployment
├── pg/
│   ├── postgres-pvc.yaml           # 持久化存储 (10Gi)
│   └── postgres-statefulset.yaml   # PostgreSQL 16 Alpine
└── svc/
    ├── backend-service.yaml        # 后端 LoadBalancer Service (localhost:8080)
    └── postgres-service.yaml       # LoadBalancer Service (localhost:30432)
```

## 快速开始

```bash
# 一键部署 PostgreSQL + 后端
./deploy/scripts/deploy.sh up

# 查看状态
./deploy/scripts/deploy.sh status

# 获取后端连接信息
./deploy/scripts/deploy.sh backend connect

# 只部署 PostgreSQL
./deploy/scripts/deploy.sh pg up

# 只部署或重建后端
./deploy/scripts/deploy.sh backend up
./deploy/scripts/deploy.sh backend build

# 获取 PostgreSQL 连接信息
./deploy/scripts/deploy.sh pg connect

# 一键进入 psql
./deploy/scripts/deploy.sh pg psql

# 卸载
./deploy/scripts/deploy.sh down
```

Windows PowerShell：

```powershell
.\deploy\scripts\deploy.ps1 up
.\deploy\scripts\deploy.ps1 status
.\deploy\scripts\deploy.ps1 backend connect
```

## 连接后端

| 方式                 | 地址                                                   |
| -------------------- | ------------------------------------------------------ |
| LoadBalancer | 通过 `./deploy/scripts/deploy.sh backend connect` 查看 |
| LoadBalancer 本地端口 | `http://localhost:8080` |
| Cluster DNS (集群内) | `http://resume-agent-backend.resume-agent:8080`        |

> 默认后端镜像名为 `resume-agent-backend:dev`，由脚本使用 Docker Desktop 本机 Docker daemon 构建，并传入 `PDFIUM_VERSION=7869`。后端 Dockerfile 会按 Docker 目标架构自动下载对应的 pdfium Linux 动态库，支持 `linux/amd64` 和 `linux/arm64`。
>
> `backend up` 构建完成后会根据镜像 ID 生成不可变部署标签，例如 `resume-agent-backend:deploy-9c827f2a681f`。这样每次构建都会触发真实的滚动更新，避免 Kubernetes 因复用 `resume-agent-backend:dev` 而继续运行旧版 API。

### 后端镜像构建加速

后端 Dockerfile 使用 **cargo-chef** 将「依赖编译」与「业务代码编译」拆成两层，并配合 BuildKit 的 `registry` / `git` / `target` 缓存：

| 变更类型 | 典型耗时（本机二次构建） |
| -------- | ------------------------ |
| 仅改 `src/` | 数十秒～数分钟（只链业务 crate） |
| 改 `Cargo.toml` / `Cargo.lock` | 与全量相近（需重编依赖） |
| 首次冷启动 | 与全量相近（需拉取并编译全部依赖） |

镜像内使用 `profile.docker`（`Cargo.toml` 中定义），关闭 LTO、提高 `codegen-units`，换取更快编译；本地发版仍可用默认 `cargo build --release`。

本地开发：`cd repo/backend && cargo docker-build`（见 `.cargo/config.toml` 别名）。

可通过环境变量覆盖构建与部署参数：

| 变量 | 默认值 | 用途 |
| ---- | ------ | ---- |
| `BACKEND_IMAGE` | `resume-agent-backend:dev` | 后端镜像名，适合切换到 registry 镜像 |
| `BACKEND_PLATFORM` | 空 | Docker 构建平台；为空时使用当前 Docker daemon 默认 Linux 平台 |
| `BACKEND_PDFIUM_VERSION` | `7869` | pdfium release 版本 |

示例：

```bash
# 构建并部署当前 Docker Desktop 节点原生平台镜像
./deploy/scripts/deploy.sh backend up

# 构建 amd64 Linux 镜像
BACKEND_PLATFORM=linux/amd64 ./deploy/scripts/deploy.sh backend build

# 构建 arm64 Linux 镜像
BACKEND_PLATFORM=linux/arm64 ./deploy/scripts/deploy.sh backend build

# 使用 registry 镜像部署
BACKEND_IMAGE=registry.example.com/resume-agent/backend:dev ./deploy/scripts/deploy.sh backend up
```

## 连接 PostgreSQL

| 方式                 | 命令                                                                             |
| -------------------- | -------------------------------------------------------------------------------- |
| LoadBalancer (宿主机直连) | `psql -h 127.0.0.1 -p 30432 -U resume_agent -d resume_agent`                 |
| GUI 数据库工具       | `Host=127.0.0.1 Port=30432 User=resume_agent Database=resume_agent`              |
| Cluster DNS (集群内) | `postgresql://resume_agent:<pwd>@resume-agent-pg.resume-agent:5432/resume_agent` |

> 当前配置面向 Docker Desktop Kubernetes：`LoadBalancer` 会把 PostgreSQL 长期暴露到宿主机 `127.0.0.1:30432`，同时保留集群内 `resume-agent-pg:5432`。

## 常用命令

| 命令              | 用途                                  |
| ----------------- | ------------------------------------- |
| `up`              | 部署 PostgreSQL 和后端                |
| `down`            | 卸载后端和 PostgreSQL（保留 Namespace） |
| `status`          | 查看 PostgreSQL 和后端状态            |
| `backend build`   | 构建本地后端镜像                      |
| `backend up`      | 构建并部署后端                        |
| `backend down`    | 卸载后端（保留 Namespace 和 PostgreSQL） |
| `backend status`  | 查看后端 Pod / Deployment / Service 状态 |
| `backend logs`    | 跟随后端日志                          |
| `backend connect` | 打印后端访问地址                      |
| `pg up`           | 部署 PostgreSQL                       |
| `pg down`         | 卸载 PostgreSQL（保留 Namespace）     |
| `pg status`       | 查看 Pod / Service / PVC 状态         |
| `pg connect`      | 打印连接字符串                        |
| `pg psql`         | 通过本地 LoadBalancer 进入 psql       |
| `help`            | 显示帮助信息                          |
