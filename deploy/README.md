# Deploy — ResumeAgent Docker Compose 部署

## 目录结构

```
deploy/
├── docker-compose.yml              # PostgreSQL + Backend
├── backend-config/
│   ├── .gitkeep
│   └── application.local.yaml      # 后端配置（gitignore）
└── README.md
```

## 快速开始

```bash
# 1. 准备配置（首次）
cp ../repo/backend/application.default.yaml deploy/backend-config/application.local.yaml
# 编辑填入真实密码、jwt_secret、master_key

# 2. 启动
cd deploy
docker compose up -d

# 3. 验证
curl http://localhost:8080/api/v1/system/health

# 4. 停止
docker compose down
```

## 端口

| 服务 | 外部端口 | 容器端口 |
|------|---------|---------|
| Backend API | `localhost:8080` | 8080 |
| PostgreSQL | `localhost:5432` | 5432 |

## 连接信息

```bash
# 后端
curl http://localhost:8080/api/v1/system/health

# PostgreSQL
psql -h 127.0.0.1 -p 5432 -U resume_agent -d resume_agent
```

## 常用命令

| 命令 | 用途 |
|------|------|
| `docker compose up -d` | 启动所有服务 |
| `docker compose down` | 停止（保留数据卷） |
| `docker compose down -v` | 停止并清空数据卷 |
| `docker compose ps` | 查看服务状态 |
| `docker compose logs -f backend` | 跟随后端日志 |
| `docker compose up -d --build backend` | 重新构建后端 |

## 配置说明

`application.default.yaml` 内置于镜像，提供 docker 环境的默认值。`backend-config/application.local.yaml` 是真正生效的配置，挂载进容器后覆盖默认值。

**注意**：`application.local.yaml` 中的 `db.password` 必须与 docker-compose 中 postgres 的 `POSTGRES_PASSWORD`（默认 `changeme`）一致。
