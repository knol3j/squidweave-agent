# SQUIDWEAVE agent: reports this machine's status every 60 seconds.
# Each report includes the GPU serial IDs so the marketplace can confirm the
# listed GPUs are the ones actually running.
import json, shutil, subprocess, sys, time, urllib.error, urllib.request

KEY = "PASTE_YOUR_MACHINE_KEY"
URL = "https://impressive-orca-501.convex.site/agent/heartbeat"

if not shutil.which("nvidia-smi"):
    sys.exit("nvidia-smi not found. Install the NVIDIA driver, then run this again.")


def number(value):
    # Some cards report "[N/A]" for load or temperature
    try:
        return float(value)
    except ValueError:
        return 0.0


def gpu_stats():
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,uuid", "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=10,
        ).stdout
    except Exception:
        return {"gpuUuids": []}
    rows = [[part.strip() for part in line.split(",")] for line in out.strip().splitlines() if line.count(",") >= 2]
    if not rows:
        return {"gpuUuids": []}
    return {
        "utilization": sum(number(r[0]) for r in rows) / len(rows),
        "gpuTempC": max(number(r[1]) for r in rows),
        "gpuUuids": [r[2] for r in rows],
    }


while True:
    body = {"agentVersion": "py-1.1", **gpu_stats()}
    req = urllib.request.Request(
        URL, data=json.dumps(body).encode(), method="POST",
        headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as res:
            reply = json.load(res)
            print(time.strftime("%H:%M:%S"), "rental active" if reply.get("rental") else "idle")
    except urllib.error.HTTPError as err:
        if err.code == 409:
            print(time.strftime("%H:%M:%S"), "hardware mismatch: these GPUs are not the ones verified for this listing. Run the hardware check again.")
        else:
            print(time.strftime("%H:%M:%S"), "heartbeat failed:", err)
    except Exception as err:
        print(time.strftime("%H:%M:%S"), "heartbeat failed:", err)
    time.sleep(60)
