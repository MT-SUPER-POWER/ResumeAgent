# Deploy — ResumeAgent Docker Compose 部署

## 目录结构

```
deploy/
├── docker-compose.yml    # PostgreSQL + Backend
└── README.md
```

## 快速开始

```bash
cd deploy

# 启动
docker compose up -d

# 验证
curl http://localhost:8080/api/v1/system/health

# 查看日志
docker compose logs -f backend

# 停止
docker compose down
```

## 端口

| 服务 | 外部端口 | 容器端口 |
|------|---------|---------|
| Backend API | `localhost:8080` | 8080 |
| PostgreSQL | `localhost:30432` | 5432 |

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
| `docker compose up -d --build backend` | 重新构建并启动后端 |

## 本地开发

本地开发不走 docker-compose，在 `repo/backend/` 下创建 `application.local.yaml` 覆盖数据库连接：

```yaml
db:
  host: 127.0.0.1
  port: 30432
  password: changeme

auth:
  jwt_secret: "your-secret"

crypto:
  master_key: "your-key"
```

`application.default.yaml` 默认值面向 docker 环境，本地开发通过 `application.local.yaml` 覆盖。
