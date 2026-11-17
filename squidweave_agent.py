# SQUIDWEAVE agent: reports this machine's status every 60 seconds.
# Each report includes the GPU IDs (NVIDIA, AMD or Intel) so the marketplace
# can confirm the listed GPUs are the ones actually running.
import glob, json, os, re, shutil, subprocess, sys, time, urllib.error, urllib.request

KEY = "PASTE_YOUR_MACHINE_KEY"
URL = "https://impressive-orca-501.convex.site/agent/heartbeat"


def number(value):
    # Some cards report "[N/A]" for load or temperature
    try:
        return float(value)
    except ValueError:
        return 0.0


def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=20).stdout
    except Exception:
        return ""


def read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return ""


def detect_gpus():
    rows = []
    if shutil.which("nvidia-smi"):
        out = run(["nvidia-smi", "--query-gpu=name,memory.total,uuid,utilization.gpu,temperature.gpu",
                   "--format=csv,noheader,nounits"])
        for line in out.strip().splitlines():
            p = [x.strip() for x in line.split(",")]
            if len(p) >= 5:
                rows.append({"name": p[0], "memoryMiB": int(number(p[1])), "uuid": p[2].replace(" ", ""),
                             "util": number(p[3]), "temp": number(p[4])})
    # AMD cards through the Linux amdgpu driver
    for card in sorted(glob.glob("/sys/class/drm/card*")):
        if "-" in os.path.basename(card):
            continue
        dev = os.path.join(card, "device")
        if read(dev + "/vendor") != "0x1002":
            continue
        mib = int(number(read(dev + "/mem_info_vram_total") or "0")) // 1048576
        if mib < 4096:
            continue
        slot = os.path.basename(os.path.realpath(dev))
        uid = read(dev + "/unique_id")
        uid = "AMD-" + uid if re.fullmatch(r"[0-9a-fA-F]+", uid) else "PCI-" + slot
        parts = run(["lspci", "-mms", slot]).split('"')
        name = parts[5].strip() if len(parts) > 5 and parts[5].strip() else "Radeon GPU"
        temps = sorted(glob.glob(dev + "/hwmon/hwmon*/temp1_input"))
        temp = number(read(temps[0]) or "0") / 1000 if temps else 0.0
        rows.append({"name": "AMD " + name, "memoryMiB": mib, "uuid": uid,
                     "util": number(read(dev + "/gpu_busy_percent") or "0"), "temp": temp})
    # Intel cards through xpu-smi
    if shutil.which("xpu-smi"):
        for line in run(["xpu-smi", "discovery", "--dump", "2,4,16"]).strip().splitlines()[1:]:
            p = [x.strip() for x in line.split(",")]
            if len(p) >= 3:
                mib = int(number(re.sub(r"[^0-9.]", "", p[2]) or "0"))
                if mib >= 4096:
                    rows.append({"name": p[0], "memoryMiB": mib, "uuid": "INTEL-" + p[1].replace(" ", ""),
                                 "util": 0.0, "temp": 0.0})
    return rows


if not detect_gpus():
    sys.exit("No supported GPU found. Install the NVIDIA driver, the AMD driver, or Intel's xpu-smi tool, then run this again.")


def gpu_stats():
    rows = detect_gpus()
    if not rows:
        return {"gpuUuids": []}
    return {
        "utilization": sum(r["util"] for r in rows) / len(rows),
        "gpuTempC": max(r["temp"] for r in rows),
        "gpuUuids": [r["uuid"] for r in rows],
    }


while True:
    body = {"agentVersion": "py-1.2", **gpu_stats()}
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
