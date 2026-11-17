# SQUIDWEAVE hardware check: reads this machine's GPUs, CPU and RAM once and sends them for verification.
import ctypes, json, os, subprocess, sys, urllib.error, urllib.request

CODE = "PASTE_YOUR_SCAN_CODE"
URL = "https://impressive-orca-501.convex.site/agent/scan"


def gpus():
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.total,uuid", "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=20,
        ).stdout
    except FileNotFoundError:
        sys.exit("nvidia-smi not found. Install the NVIDIA driver, then run this again.")
    rows = []
    for line in out.strip().splitlines():
        name, memory, uuid = [part.strip() for part in line.split(",")]
        rows.append({"name": name, "memoryMiB": int(float(memory)), "uuid": uuid})
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


body = {"code": CODE, "gpus": gpus(), "cpuCores": os.cpu_count() or 0, "ramMiB": ram_mib()}
req = urllib.request.Request(URL, data=json.dumps(body).encode(), method="POST",
                             headers={"Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=20) as res:
        print("Verified. Go back to the website to finish your listing.")
except urllib.error.HTTPError as err:
    print("Verification failed:", json.load(err).get("error"))
