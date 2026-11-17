# SQUIDWEAVE agent: reports this machine's status every 60 seconds.
import json, shutil, subprocess, time, urllib.request

KEY = "PASTE_YOUR_MACHINE_KEY"
URL = "https://impressive-orca-501.convex.site/agent/heartbeat"


def gpu_stats():
    if not shutil.which("nvidia-smi"):
        return {}
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=10,
        ).stdout
        rows = [[float(x) for x in line.split(",")] for line in out.strip().splitlines() if line.strip()]
    except Exception:
        return {}
    if not rows:
        return {}
    return {"utilization": sum(r[0] for r in rows) / len(rows), "gpuTempC": max(r[1] for r in rows)}


while True:
    body = {"agentVersion": "py-1.0", **gpu_stats()}
    req = urllib.request.Request(
        URL, data=json.dumps(body).encode(), method="POST",
        headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as res:
            reply = json.load(res)
            print(time.strftime("%H:%M:%S"), "rental active" if reply.get("rental") else "idle")
    except Exception as err:
        print(time.strftime("%H:%M:%S"), "heartbeat failed:", err)
    time.sleep(60)
