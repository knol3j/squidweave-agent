#!/usr/bin/env bash
# SQUIDWEAVE agent: reports this machine's status every 60 seconds.
# Each report includes the GPU IDs (NVIDIA, AMD or Intel) so the marketplace
# can confirm the listed GPUs are the ones actually running.
SQUIDWEAVE_KEY="PASTE_YOUR_MACHINE_KEY"
SQUIDWEAVE_URL="https://impressive-orca-501.convex.site/agent/heartbeat"

detect_gpus() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=name,memory.total,uuid,utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null |
      awk -F', *' 'NF>=3 {gsub(/ /, "", $3); printf "%s\t%d\t%s\t%d\t%d\n", $1, $2, $3, $4+0, $5+0}'
  fi
  for card in /sys/class/drm/card*; do
    case "$(basename "$card")" in *-*) continue ;; esac
    dev="$card/device"
    [ -r "$dev/vendor" ] && [ -r "$dev/mem_info_vram_total" ] || continue
    [ "$(cat "$dev/vendor")" = "0x1002" ] || continue
    mib=$(( $(cat "$dev/mem_info_vram_total") / 1048576 ))
    [ "$mib" -ge 4096 ] || continue
    slot=$(basename "$(readlink -f "$dev")")
    id=$(cat "$dev/unique_id" 2>/dev/null)
    case "$id" in "" | *[!0-9a-fA-F]*) id="PCI-$slot" ;; *) id="AMD-$id" ;; esac
    name=$(lspci -mms "$slot" 2>/dev/null | awk -F'"' '{print $6}')
    [ -n "$name" ] || name="Radeon GPU"
    util=$(cat "$dev/gpu_busy_percent" 2>/dev/null)
    temp=$(cat "$dev"/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1)
    [ -n "$temp" ] || temp=0
    printf "AMD %s\t%d\t%s\t%d\t%d\n" "$name" "$mib" "$id" "$(( util + 0 ))" "$(( temp / 1000 ))"
  done
  if command -v xpu-smi >/dev/null 2>&1; then
    xpu-smi discovery --dump 2,4,16 2>/dev/null |
      awk -F', *' 'NR>1 && NF>=3 {gsub(/ /, "", $2); gsub(/[^0-9.]/, "", $3); if ($3+0 >= 4096) printf "%s\t%d\tINTEL-%s\t0\t0\n", $1, $3, $2}'
  fi
}

if [ -z "$(detect_gpus)" ]; then
  echo "No supported GPU found. Install the NVIDIA driver, the AMD driver, or Intel's xpu-smi tool, then run this again."
  exit 1
fi

while true; do
  # Average load across all GPUs, hottest GPU temperature, and every GPU ID
  BODY=$(detect_gpus | awk -F'\t' 'NF>=3 {u+=$4; if ($5>t) t=$5; ids=ids (n++?",":"") "\"" $3 "\""}
    END {printf "{\"utilization\": %d, \"gpuTempC\": %d, \"gpuUuids\": [%s], \"agentVersion\": \"bash-1.2\"}", (n?u/n:0), t, ids}')
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
