#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAMESPACE="resume-agent"
BACKEND_IMAGE="${BACKEND_IMAGE:-resume-agent-backend:dev}"
BACKEND_PDFIUM_VERSION="${BACKEND_PDFIUM_VERSION:-7869}"
BACKEND_PLATFORM="${BACKEND_PLATFORM:-}"

help() {
  cat <<EOF

  ResumeAgent Deploy Manager

  Usage: deploy.sh <command> [subcommand]

  PostgreSQL
    pg up          Deploy PostgreSQL (StatefulSet + PVC + SVC)
    pg down        Teardown PostgreSQL
    pg status      Show pod and service status
    pg connect     Print connection strings
    pg psql        Open psql shell through localhost LoadBalancer

  Backend
    backend build   Build backend image for Docker Desktop
    backend up      Deploy backend (build image + Deployment + SVC)
    backend down    Teardown backend
    backend status  Show backend pod and service status
    backend logs    Follow backend logs
    backend connect Print backend endpoints

  All
    up             Deploy PostgreSQL and backend
    down           Teardown backend and PostgreSQL
    status         Show PostgreSQL and backend status

  Global
    help           Show this message

EOF
  exit 0
}

pg_up() {
  echo "[1/4] namespace"
  kubectl apply -f "$ROOT/namespace.yaml"
  echo "[2/4] secret"
  kubectl apply -f "$ROOT/secret.yaml"
  echo "[3/4] statefulset + pvc"
  kubectl apply -f "$ROOT/pg/postgres-pvc.yaml"
  kubectl apply -f "$ROOT/pg/postgres-statefulset.yaml"
  echo "[4/4] service"
  kubectl apply -f "$ROOT/svc/postgres-service.yaml"

  echo "Waiting for pod..."
  kubectl wait --for=condition=ready pod -l app=resume-agent-pg -n "$NAMESPACE" --timeout=120s
  echo "Done. Run 'deploy.sh pg connect' for connection info."
}

pg_down() {
  kubectl delete -f "$ROOT/svc/postgres-service.yaml" --ignore-not-found
  kubectl delete -f "$ROOT/pg/postgres-statefulset.yaml" --ignore-not-found
  kubectl delete -f "$ROOT/pg/postgres-pvc.yaml" --ignore-not-found
  kubectl delete -f "$ROOT/secret.yaml" --ignore-not-found
  echo "PostgreSQL removed. Namespace kept."
}

pg_connect() {
  echo ""
  echo "=== PostgreSQL ==="
  echo ""
  echo "  local:         psql -h 127.0.0.1 -p 30432 -U resume_agent -d resume_agent"
  echo "  GUI tools:     Host=127.0.0.1  Port=30432  User=resume_agent  DB=resume_agent"
  echo "  cluster dns:   postgresql://resume_agent:<pwd>@resume-agent-pg.resume-agent:5432/resume_agent"
  echo ""
}

pg_status() {
  echo "=== Pods ==="
  kubectl get pods -l app=resume-agent-pg -n "$NAMESPACE"
  echo ""
  echo "=== Service ==="
  kubectl get svc resume-agent-pg -n "$NAMESPACE" 2>/dev/null
  echo ""
  echo "=== PVC ==="
  kubectl get pvc -l app=resume-agent-pg -n "$NAMESPACE" 2>/dev/null
}

pg_psql() {
  PGPASSWORD=changeme-in-production psql -h 127.0.0.1 -p 30432 -U resume_agent -d resume_agent
}

backend_build() {
  # NOTE: BuildKit 启用 cache mount（Dockerfile syntax=docker/dockerfile:1）
  export DOCKER_BUILDKIT=1
  if [ -n "$BACKEND_PLATFORM" ]; then
    docker build \
      --platform "$BACKEND_PLATFORM" \
      --build-arg "PDFIUM_VERSION=$BACKEND_PDFIUM_VERSION" \
      -t "$BACKEND_IMAGE" \
      -f "$ROOT/../repo/backend/.docker/Dockerfile" \
      "$ROOT/../repo/backend"
    return
  fi

  docker build \
    --build-arg "PDFIUM_VERSION=$BACKEND_PDFIUM_VERSION" \
    -t "$BACKEND_IMAGE" \
    -f "$ROOT/../repo/backend/.docker/Dockerfile" \
    "$ROOT/../repo/backend"
}

backend_prepare_deploy_image() {
  local image_id
  local source_tag
  local image_repo
  local deploy_image

  image_id="$(docker image inspect --format '{{.Id}}' "$BACKEND_IMAGE")"
  image_id="${image_id#sha256:}"
  source_tag="$(docker image inspect --format '{{index .RepoTags 0}}' "$BACKEND_IMAGE")"
  image_repo="${source_tag%:*}"
  deploy_image="${image_repo}:deploy-${image_id:0:12}"

  # NOTE: 唯一标签确保 Docker Desktop Kubernetes 不会复用旧的 :dev 镜像。
  docker tag "$BACKEND_IMAGE" "$deploy_image"
  printf '%s\n' "$deploy_image"
}

backend_apply() {
  local deploy_image="${1:-$BACKEND_IMAGE}"

  kubectl apply -f "$ROOT/backend/backend-serviceaccount.yaml"
  kubectl apply -f "$ROOT/backend/backend-secret.yaml"
  kubectl apply -f "$ROOT/backend/backend-deployment.yaml"
  kubectl apply -f "$ROOT/svc/backend-service.yaml"
  kubectl set image deployment/resume-agent-backend backend="$deploy_image" -n "$NAMESPACE"
}

backend_up() {
  local deploy_image

  echo "[1/4] namespace"
  kubectl apply -f "$ROOT/namespace.yaml"
  echo "[2/4] PostgreSQL"
  pg_up
  echo "[3/4] backend image"
  backend_build
  deploy_image="$(backend_prepare_deploy_image)"
  echo "Deploy image: $deploy_image"
  echo "[4/4] backend workload"
  backend_apply "$deploy_image"

  echo "Waiting for backend..."
  kubectl rollout status deployment/resume-agent-backend -n "$NAMESPACE" --timeout=180s
  echo "Done. Run 'deploy.sh backend connect' for endpoint info."
}

backend_down() {
  kubectl delete -f "$ROOT/svc/backend-service.yaml" --ignore-not-found
  kubectl delete -f "$ROOT/backend/backend-deployment.yaml" --ignore-not-found
  kubectl delete -f "$ROOT/backend/backend-secret.yaml" --ignore-not-found
  kubectl delete -f "$ROOT/backend/backend-serviceaccount.yaml" --ignore-not-found
  echo "Backend removed. Namespace and PostgreSQL kept."
}

backend_status() {
  echo "=== Pods ==="
  kubectl get pods -l app=resume-agent-backend -n "$NAMESPACE"
  echo ""
  echo "=== Deployment ==="
  kubectl get deployment resume-agent-backend -n "$NAMESPACE" 2>/dev/null
  echo ""
  echo "=== Service ==="
  kubectl get svc resume-agent-backend -n "$NAMESPACE" 2>/dev/null
}

backend_logs() {
  kubectl logs -l app=resume-agent-backend -n "$NAMESPACE" --tail=100 -f
}

backend_connect() {
  local lb_ip
  local service_port
  lb_ip="$(kubectl get svc resume-agent-backend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  service_port="$(kubectl get svc resume-agent-backend -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || true)"

  echo ""
  echo "=== Backend ==="
  echo ""
  if [ -n "$service_port" ]; then
    echo "  local:         http://localhost:$service_port"
  fi
  if [ -n "$lb_ip" ]; then
    echo "  load balancer: http://$lb_ip:30080"
  fi
  echo "  cluster dns:   http://resume-agent-backend.resume-agent:8080"
  echo "  image:         $BACKEND_IMAGE"
  echo ""
}

all_status() {
  pg_status
  echo ""
  backend_status
}

case "${1:-help}" in
  help|-h|--help) help ;;
  up) backend_up ;;
  down)
    backend_down
    pg_down
    ;;
  status) all_status ;;
  pg)
    case "${2:-}" in
      up)      pg_up ;;
      down)    pg_down ;;
      connect) pg_connect ;;
      status)  pg_status ;;
      psql)    pg_psql ;;
      *)       help ;;
    esac
    ;;
  backend)
    case "${2:-}" in
      build)   backend_build ;;
      up)      backend_up ;;
      down)    backend_down ;;
      connect) backend_connect ;;
      status)  backend_status ;;
      logs)    backend_logs ;;
      *)       help ;;
    esac
    ;;
  *) help ;;
esac
