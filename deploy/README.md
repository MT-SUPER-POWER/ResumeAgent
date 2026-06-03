# Deploy — ResumeAgent Docker Compose 部署

## 目录结构

```
deploy/
├── docker-compose.yml              # 一键部署 PostgreSQL + Backend
├── backend-config/
│   ├── .gitkeep
│   └── application.local.yaml      # 后端配置（gitignore，需手动创建）
└── README.md
```

## 快速开始

```bash
# 1. 准备后端配置文件
cp ../repo/backend/application.default.yaml deploy/backend-config/application.local.yaml
# 编辑 application.local.yaml，填入真实 db 密码、jwt_secret、master_key 等
# db.host 改为 postgres（docker-compose 服务名）

# 2. 启动
cd deploy
docker compose up -d

# 3. 查看状态
docker compose ps
docker compose logs -f backend

# 4. 停止
docker compose down

# 5. 停止并清空数据
docker compose down -v
```

## 端口

| 服务 | 外部端口 | 容器端口 | 说明 |
|------|---------|---------|------|
| Backend API | `localhost:8080` | 8080 | REST API |
| PostgreSQL | `localhost:30432` | 5432 | 数据库 |

## 连接信息

```bash
# 后端
curl http://localhost:8080/api/v1/system/health

# PostgreSQL
psql -h 127.0.0.1 -p 30432 -U resume_agent -d resume_agent
```

## 常用命令

| 命令 | 用途 |
|------|------|
| `docker compose up -d` | 启动所有服务 |
| `docker compose down` | 停止并移除容器（保留数据卷） |
| `docker compose down -v` | 停止并清空数据卷 |
| `docker compose ps` | 查看服务状态 |
| `docker compose logs -f backend` | 跟随后端日志 |
| `docker compose logs -f postgres` | 跟随数据库日志 |
| `docker compose restart backend` | 重启后端 |
| `docker compose up -d --build backend` | 重新构建并启动后端 |

## 后端镜像构建加速

后端 Dockerfile 使用 **cargo-chef** 将「依赖编译」与「业务代码编译」拆成两层，并配合 BuildKit 缓存：

| 变更类型 | 典型耗时（二次构建） |
|----------|---------------------|
| 仅改 `src/` | 数十秒～数分钟（只链业务 crate） |
| 改 `Cargo.toml` / `Cargo.lock` | 与全量相近（需重编依赖） |
| 首次冷启动 | 与全量相近（需拉取并编译全部依赖） |

## application.local.yaml 关键配置

容器内 db.host 必须指向 docker-compose 服务名：

```yaml
db:
  host: postgres          # 不是 127.0.0.1，而是 docker-compose 服务名
  port: 5432              # 容器内端口
  username: resume_agent
  password: changeme      # 与 DB_PASSWORD 环境变量一致
  db_name: resume_agent
  max_connections: 20

server:
  port: 8080

# ... 其余配置项
```
