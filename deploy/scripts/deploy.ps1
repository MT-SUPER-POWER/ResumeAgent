$ErrorActionPreference = "Stop"
$ROOT = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Namespace = "resume-agent"
$BackendImage = if ($env:BACKEND_IMAGE) { $env:BACKEND_IMAGE } else { "resume-agent-backend:dev" }
$BackendPdfiumVersion = if ($env:BACKEND_PDFIUM_VERSION) { $env:BACKEND_PDFIUM_VERSION } else { "7869" }
$BackendPlatform = if ($env:BACKEND_PLATFORM) { $env:BACKEND_PLATFORM } else { "" }

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
  Write-Host "Backend" -ForegroundColor Yellow -NoNewline
  Write-Host "==================================================="

  $backendCmds = @(
    @{cmd="backend build";  desc="Build backend image for Docker Desktop"},
    @{cmd="backend up";     desc="Deploy backend (build image + Deployment + SVC)"},
    @{cmd="backend down";   desc="Teardown backend"},
    @{cmd="backend status"; desc="Show backend pod and service status"},
    @{cmd="backend logs";   desc="Follow backend logs"},
    @{cmd="backend connect";desc="Print backend endpoints"}
  )
  foreach ($c in $backendCmds) {
    Write-Host "    " -NoNewline
    Write-Host $c.cmd.PadRight(16) -ForegroundColor Green -NoNewline
    Write-Host $c.desc
  }
  Write-Host ""

  Write-Host "  " -NoNewline
  Write-Host "All" -ForegroundColor Yellow -NoNewline
  Write-Host "======================================================="
  $allCmds = @(
    @{cmd="up";     desc="Deploy PostgreSQL and backend"},
    @{cmd="down";   desc="Teardown backend and PostgreSQL"},
    @{cmd="status"; desc="Show PostgreSQL and backend status"}
  )
  foreach ($c in $allCmds) {
    Write-Host "    " -NoNewline
    Write-Host $c.cmd.PadRight(16) -ForegroundColor Green -NoNewline
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
  kubectl apply -f "$ROOT\pg\postgres-pvc.yaml"
  kubectl apply -f "$ROOT\pg\postgres-statefulset.yaml"
  Write-Host "[4/4] service" -ForegroundColor Yellow
  kubectl apply -f "$ROOT\svc\postgres-service.yaml"

  Write-Host "Waiting for pod..." -ForegroundColor Cyan
  kubectl wait --for=condition=ready pod -l app=resume-agent-pg -n $Namespace --timeout=120s
  Write-Host "Done. Run 'deploy.ps1 pg connect' for connection info." -ForegroundColor Green
}

function Pg-Down {
  kubectl delete -f "$ROOT\svc\postgres-service.yaml" --ignore-not-found
  kubectl delete -f "$ROOT\pg\postgres-statefulset.yaml" --ignore-not-found
  kubectl delete -f "$ROOT\pg\postgres-pvc.yaml" --ignore-not-found
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

function Backend-Build {
  $dockerArgs = @("build")
  if ($BackendPlatform) {
    $dockerArgs += @("--platform", $BackendPlatform)
  }

  $dockerArgs += @(
    "--build-arg", "PDFIUM_VERSION=$BackendPdfiumVersion",
    "-t", $BackendImage,
    "-f", "$ROOT\..\repo\backend\.docker\Dockerfile",
    "$ROOT\..\repo\backend"
  )

  & docker @dockerArgs
}

function Backend-Apply {
  kubectl apply -f "$ROOT\backend\backend-serviceaccount.yaml"
  kubectl apply -f "$ROOT\backend\backend-secret.yaml"
  kubectl apply -f "$ROOT\backend\backend-deployment.yaml"
  kubectl apply -f "$ROOT\svc\backend-service.yaml"
  kubectl set image deployment/resume-agent-backend "backend=$BackendImage" -n $Namespace
}

function Backend-Up {
  Write-Host "[1/4] namespace" -ForegroundColor Yellow
  kubectl apply -f "$ROOT\namespace.yaml"
  Write-Host "[2/4] PostgreSQL" -ForegroundColor Yellow
  Pg-Up
  Write-Host "[3/4] backend image" -ForegroundColor Yellow
  Backend-Build
  Write-Host "[4/4] backend workload" -ForegroundColor Yellow
  Backend-Apply
  kubectl rollout restart deployment/resume-agent-backend -n $Namespace

  Write-Host "Waiting for backend..." -ForegroundColor Cyan
  kubectl wait --for=condition=available deployment/resume-agent-backend -n $Namespace --timeout=180s
  Write-Host "Done. Run 'deploy.ps1 backend connect' for endpoint info." -ForegroundColor Green
}

function Backend-Down {
  kubectl delete -f "$ROOT\svc\backend-service.yaml" --ignore-not-found
  kubectl delete -f "$ROOT\backend\backend-deployment.yaml" --ignore-not-found
  kubectl delete -f "$ROOT\backend\backend-secret.yaml" --ignore-not-found
  kubectl delete -f "$ROOT\backend\backend-serviceaccount.yaml" --ignore-not-found
  Write-Host "Backend removed. Namespace and PostgreSQL kept." -ForegroundColor Green
}

function Backend-Status {
  Write-Host "=== Pods ===" -ForegroundColor Cyan
  kubectl get pods -l app=resume-agent-backend -n $Namespace
  Write-Host ""
  Write-Host "=== Deployment ===" -ForegroundColor Cyan
  kubectl get deployment resume-agent-backend -n $Namespace 2>$null
  Write-Host ""
  Write-Host "=== Service ===" -ForegroundColor Cyan
  kubectl get svc resume-agent-backend -n $Namespace 2>$null
}

function Backend-Logs {
  kubectl logs -l app=resume-agent-backend -n $Namespace --tail=100 -f
}

function Backend-Connect {
  $lbIp = ""
  $servicePort = ""
  try {
    $lbIp = kubectl get svc resume-agent-backend -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    $servicePort = kubectl get svc resume-agent-backend -n $Namespace -o jsonpath='{.spec.ports[0].port}' 2>$null
  } catch {
    $lbIp = ""
    $servicePort = ""
  }

  Write-Host ""
  Write-Host "=== Backend ===" -ForegroundColor Cyan
  Write-Host ""
  if ($servicePort) {
    Write-Host "  local:         http://localhost:$servicePort"
  }
  if ($lbIp) {
    Write-Host "  load balancer: http://$lbIp:30080"
  }
  Write-Host "  cluster dns:   http://resume-agent-backend.resume-agent:8080"
  Write-Host "  image:         $BackendImage"
  Write-Host ""
}

function All-Status {
  Pg-Status
  Write-Host ""
  Backend-Status
}

switch ($args[0]) {
  "help"   { Help }
  "up"     { Backend-Up }
  "down"   {
    Backend-Down
    Pg-Down
  }
  "status" { All-Status }
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
  "backend" {
    switch ($args[1]) {
      "build"   { Backend-Build }
      "up"      { Backend-Up }
      "down"    { Backend-Down }
      "connect" { Backend-Connect }
      "status"  { Backend-Status }
      "logs"    { Backend-Logs }
      default   { Help }
    }
  }
  default { Help }
}
