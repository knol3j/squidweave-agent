#!/usr/bin/env bash
# SQUIDWEAVE hardware check: reads this machine's GPUs, CPU and RAM once and sends them for verification.
CODE="PASTE_YOUR_SCAN_CODE"
URL="https://impressive-orca-501.convex.site/agent/scan"

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi not found. Install the NVIDIA driver, then run this again."
  exit 1
fi
GPUS=$(nvidia-smi --query-gpu=name,memory.total,uuid --format=csv,noheader,nounits |
  awk -F', ' '{gsub(/"/, "", $1); printf "%s{\"name\":\"%s\",\"memoryMiB\":%d,\"uuid\":\"%s\"}", (NR>1?",":""), $1, $2, $3}')
CORES=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu)
if [ -r /proc/meminfo ]; then
  RAM=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
else
  RAM=$(( $(sysctl -n hw.memsize) / 1048576 ))
fi

curl -sS -X POST "$URL" -H "Content-Type: application/json" \
  -d "{\"code\":\"$CODE\",\"gpus\":[$GPUS],\"cpuCores\":$CORES,\"ramMiB\":$RAM}"
echo
