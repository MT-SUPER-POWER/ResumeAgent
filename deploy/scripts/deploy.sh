#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAMESPACE="resume-agent"

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
  kubectl apply -f "$ROOT/pod/postgres-pvc.yaml"
  kubectl apply -f "$ROOT/pod/postgres-statefulset.yaml"
  echo "[4/4] service"
  kubectl apply -f "$ROOT/svc/postgres-service.yaml"

  echo "Waiting for pod..."
  kubectl wait --for=condition=ready pod -l app=resume-agent-pg -n "$NAMESPACE" --timeout=120s
  echo "Done. Run 'deploy.sh pg connect' for connection info."
}

pg_down() {
  kubectl delete -f "$ROOT/svc/postgres-service.yaml" --ignore-not-found
  kubectl delete -f "$ROOT/pod/postgres-statefulset.yaml" --ignore-not-found
  kubectl delete -f "$ROOT/pod/postgres-pvc.yaml" --ignore-not-found
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

case "${1:-help}" in
  help|-h|--help) help ;;
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
  *) help ;;
esac
