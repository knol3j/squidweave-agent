#!/usr/bin/env bash
# SQUIDWEAVE agent: reports this machine's status every 60 seconds.
# Each report includes the GPU serial IDs so the marketplace can confirm the
# listed GPUs are the ones actually running.
SQUIDWEAVE_KEY="PASTE_YOUR_MACHINE_KEY"
SQUIDWEAVE_URL="https://impressive-orca-501.convex.site/agent/heartbeat"

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi not found. Install the NVIDIA driver, then run this again."
  exit 1
fi

while true; do
  # Average load across all GPUs, hottest GPU temperature ("[N/A]" readings count as 0), and every GPU serial ID
  read -r UTIL TEMP < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
    --format=csv,noheader,nounits | awk -F', ' '{u+=($1+0); if(($2+0)>t)t=$2+0; n++} END {if(n) printf "%d %d", u/n, t}')
  UUIDS=$(nvidia-smi --query-gpu=uuid --format=csv,noheader | awk '{gsub(/ /, ""); printf "%s\"%s\"", (NR>1?",":""), $0}')
  BODY="{\"utilization\": ${UTIL:-0}, \"gpuTempC\": ${TEMP:-0}, \"gpuUuids\": [$UUIDS], \"agentVersion\": \"bash-1.1\"}"
  REPLY=$(curl -sS -X POST "$SQUIDWEAVE_URL" \
    -H "Authorization: Bearer $SQUIDWEAVE_KEY" \
    -H "Content-Type: application/json" \
    -d "$BODY" -w "\n%{http_code}")
  CODE=$(echo "$REPLY" | tail -n1)
  if [ "$CODE" = "200" ]; then
    echo "$(date +%T) heartbeat sent"
  elif [ "$CODE" = "409" ]; then
    echo "$(date +%T) hardware mismatch: these GPUs are not the ones verified for this listing. Run the hardware check again."
  else
    echo "$(date +%T) heartbeat failed ($CODE)"
  fi
  sleep 60
done
