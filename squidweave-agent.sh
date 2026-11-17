#!/usr/bin/env bash
# SQUIDWEAVE agent: reports this machine's status every 60 seconds.
SQUIDWEAVE_KEY="PASTE_YOUR_MACHINE_KEY"
SQUIDWEAVE_URL="https://impressive-orca-501.convex.site/agent/heartbeat"

while true; do
  BODY='{"agentVersion": "bash-1.0"}'
  if command -v nvidia-smi >/dev/null 2>&1; then
    # Average load across all GPUs, hottest GPU temperature
    read -r UTIL TEMP < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
      --format=csv,noheader,nounits | awk -F', ' '{u+=$1; if($2>t)t=$2; n++} END {if(n) printf "%d %d", u/n, t}')
    if [ -n "$UTIL" ]; then
      BODY="{\"utilization\": $UTIL, \"gpuTempC\": $TEMP, \"agentVersion\": \"bash-1.0\"}"
    fi
  fi
  if curl -fsS -X POST "$SQUIDWEAVE_URL" \
    -H "Authorization: Bearer $SQUIDWEAVE_KEY" \
    -H "Content-Type: application/json" \
    -d "$BODY" >/dev/null; then
    echo "$(date +%T) heartbeat sent"
  else
    echo "$(date +%T) heartbeat failed"
  fi
  sleep 60
done
