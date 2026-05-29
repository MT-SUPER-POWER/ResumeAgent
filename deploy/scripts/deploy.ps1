$ErrorActionPreference = "Stop"
$ROOT = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Namespace = "resume-agent"

function Help {
  Write-Host ""
  Write-Host "  ResumeAgent Deploy Manager" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "  Usage: deploy.ps1 <command> [subcommand]" -ForegroundColor White
  Write-Host ""

  Write-Host "  " -NoNewline
  Write-Host "PostgreSQL" -ForegroundColor Yellow -NoNewline
  Write-Host "================================================"

  $cmds = @(
    @{cmd="pg up";       desc="Deploy PostgreSQL (StatefulSet + PVC + SVC)"},
    @{cmd="pg down";     desc="Teardown PostgreSQL"},
    @{cmd="pg status";   desc="Show pod and service status"},
    @{cmd="pg connect";  desc="Print connection strings"},
    @{cmd="pg psql";     desc="Open psql shell through localhost LoadBalancer"}
  )
  foreach ($c in $cmds) {
    Write-Host "    " -NoNewline
    Write-Host $c.cmd.PadRight(14) -ForegroundColor Green -NoNewline
    Write-Host $c.desc
  }
  Write-Host ""

  Write-Host "  " -NoNewline
  Write-Host "Global" -ForegroundColor Yellow -NoNewline
  Write-Host "================================================"
  Write-Host "    " -NoNewline
  Write-Host "help".PadRight(14) -ForegroundColor Green -NoNewline
  Write-Host "Show this message"
  Write-Host ""

  exit 0
}

function Pg-Up {
  Write-Host "[1/4] namespace" -ForegroundColor Yellow
  kubectl apply -f "$ROOT\namespace.yaml"
  Write-Host "[2/4] secret" -ForegroundColor Yellow
  kubectl apply -f "$ROOT\secret.yaml"
  Write-Host "[3/4] statefulset + pvc" -ForegroundColor Yellow
  kubectl apply -f "$ROOT\pod\postgres-pvc.yaml"
  kubectl apply -f "$ROOT\pod\postgres-statefulset.yaml"
  Write-Host "[4/4] service" -ForegroundColor Yellow
  kubectl apply -f "$ROOT\svc\postgres-service.yaml"

  Write-Host "Waiting for pod..." -ForegroundColor Cyan
  kubectl wait --for=condition=ready pod -l app=resume-agent-pg -n $Namespace --timeout=120s
  Write-Host "Done. Run 'deploy.ps1 pg connect' for connection info." -ForegroundColor Green
}

function Pg-Down {
  kubectl delete -f "$ROOT\svc\postgres-service.yaml" --ignore-not-found
  kubectl delete -f "$ROOT\pod\postgres-statefulset.yaml" --ignore-not-found
  kubectl delete -f "$ROOT\pod\postgres-pvc.yaml" --ignore-not-found
  kubectl delete -f "$ROOT\secret.yaml" --ignore-not-found
  Write-Host "PostgreSQL removed. Namespace kept." -ForegroundColor Green
}

function Pg-Connect {
  Write-Host ""
  Write-Host "=== PostgreSQL ===" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "  local:        psql -h 127.0.0.1 -p 30432 -U resume_agent -d resume_agent"
  Write-Host "  GUI tools:     Host=127.0.0.1  Port=30432  User=resume_agent  DB=resume_agent"
  Write-Host "  cluster dns:   postgresql://resume_agent:<pwd>@resume-agent-pg.resume-agent:5432/resume_agent"
  Write-Host ""
}

function Pg-Status {
  Write-Host "=== Pods ===" -ForegroundColor Cyan
  kubectl get pods -l app=resume-agent-pg -n $Namespace
  Write-Host ""
  Write-Host "=== Service ===" -ForegroundColor Cyan
  kubectl get svc resume-agent-pg -n $Namespace 2>$null
  Write-Host ""
  Write-Host "=== PVC ===" -ForegroundColor Cyan
  kubectl get pvc -l app=resume-agent-pg -n $Namespace 2>$null
}

function Pg-Psql {
  $env:PGPASSWORD = "changeme-in-production"
  psql -h 127.0.0.1 -p 30432 -U resume_agent -d resume_agent
}

switch ($args[0]) {
  "help"   { Help }
  "pg" {
    switch ($args[1]) {
      "up"      { Pg-Up }
      "down"    { Pg-Down }
      "connect" { Pg-Connect }
      "status"  { Pg-Status }
      "psql"    { Pg-Psql }
      default   { Help }
    }
  }
  default { Help }
}
