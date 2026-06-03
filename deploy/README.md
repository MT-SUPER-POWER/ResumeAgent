# Deploy — ResumeAgent Docker Compose 部署

## 快速开始

```bash
cd deploy
cp .env.example .env    # 首次，编辑填入密钥
docker compose up -d     # 启动

curl http://localhost:8080/api/v1/system/health
```

## 端口

| 服务 | 地址 |
|------|------|
| Backend API | `http://localhost:8080` |
| PostgreSQL | `localhost:5432` |

## 常用命令

| 命令 | 用途 |
|------|------|
| `docker compose up -d` | 启动 |
| `docker compose down` | 停止（保留数据） |
| `docker compose down -v` | 停止并清空数据 |
| `docker compose ps` | 查看状态 |
| `docker compose logs -f backend` | 跟随后端日志 |
| `docker compose up -d --build backend` | 重建后端 |

## 配置

所有配置通过 `.env` 环境变量管理。复制 `.env.example` 修改即可，注释掉的行使用默认值。

本地开发同样通过 `RA_*` 环境变量配置。
