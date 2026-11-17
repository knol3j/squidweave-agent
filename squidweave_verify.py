# SQUIDWEAVE hardware check: reads this machine's GPUs (NVIDIA, AMD or Intel), CPU and RAM once and sends them for verification.
import ctypes, glob, json, os, re, shutil, subprocess, sys, urllib.error, urllib.request

CODE = "PASTE_YOUR_SCAN_CODE"
URL = "https://impressive-orca-501.convex.site/agent/scan"


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


def ram_mib():
    if hasattr(os, "sysconf"):
        return os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES") // 1048576

    class Status(ctypes.Structure):
        _fields_ = [("length", ctypes.c_ulong), ("load", ctypes.c_ulong), ("total", ctypes.c_ulonglong),
                    ("avail", ctypes.c_ulonglong), ("pt", ctypes.c_ulonglong), ("pa", ctypes.c_ulonglong),
                    ("vt", ctypes.c_ulonglong), ("va", ctypes.c_ulonglong), ("ext", ctypes.c_ulonglong)]

    status = Status()
    status.length = ctypes.sizeof(Status)
    ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status))
    return status.total // 1048576


found = [{"name": g["name"], "memoryMiB": g["memoryMiB"], "uuid": g["uuid"]} for g in detect_gpus()]
if not found:
    sys.exit("No supported GPU found. Install the NVIDIA driver, the AMD driver, or Intel's xpu-smi tool, then run this again.")
body = {"code": CODE, "gpus": found, "cpuCores": os.cpu_count() or 0, "ramMiB": ram_mib()}
req = urllib.request.Request(URL, data=json.dumps(body).encode(), method="POST",
                             headers={"Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=20) as res:
        print("Verified. Go back to the website to finish your listing.")
except urllib.error.HTTPError as err:
    print("Verification failed:", json.load(err).get("error"))
