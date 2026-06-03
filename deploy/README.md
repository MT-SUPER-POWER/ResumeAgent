# Deploy — ResumeAgent Docker Compose 部署

## 目录结构

```
deploy/
├── docker-compose.yml    # PostgreSQL + Backend
├── .env.example          # 环境变量模板
├── .env                  # 实际配置（gitignore）
└── README.md
```

## 快速开始

```bash
# 1. 创建 .env（首次）
cp .env.example .env
# 编辑填入真实值

# 2. 启动
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
| `docker compose up -d` | 启动 |
| `docker compose down` | 停止（保留数据卷） |
| `docker compose down -v` | 停止并清空数据卷 |
| `docker compose ps` | 查看状态 |
| `docker compose logs -f backend` | 跟随后端日志 |
| `docker compose up -d --build backend` | 重新构建后端 |

## 配置

镜像内置 `application.default.yaml` 提供默认值。`.env` 中的 `RA_*` 环境变量覆盖密钥等敏感配置，优先级高于 yaml。

本地开发不走 docker-compose，在 `repo/backend/` 下创建 `application.local.yaml` 覆盖本地值。
