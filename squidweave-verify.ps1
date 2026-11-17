# SQUIDWEAVE hardware check: reads this machine's GPUs (NVIDIA, AMD or Intel), CPU and RAM once and sends them for verification.
$Code = "PASTE_YOUR_SCAN_CODE"
$Url = "https://impressive-orca-501.convex.site/agent/scan"

function Get-Gpus {
  $list = @()
  if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    $list += @(nvidia-smi --query-gpu=name,memory.total,uuid,utilization.gpu,temperature.gpu --format=csv,noheader,nounits | ForEach-Object {
      $p = $_ -split ",\s*"
      # Some cards report "[N/A]" for load or temperature
      $u = 0.0; $t = 0.0
      [void][double]::TryParse($p[3], [ref]$u); [void][double]::TryParse($p[4], [ref]$t)
      [pscustomobject]@{ name = $p[0].Trim(); memoryMiB = [int]$p[1]; uuid = $p[2].Trim(); util = $u; temp = $t }
    })
  }
  # AMD and Intel: the driver's registry entry holds the real memory size (Windows' own field caps at 4 GB)
  $mem = @{}
  Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -ErrorAction SilentlyContinue | ForEach-Object {
    try {
      $p = Get-ItemProperty $_.PSPath -ErrorAction Stop
      $size = $p.'HardwareInformation.qwMemorySize'
      if ($p.DriverDesc -and $size) { $mem[$p.DriverDesc] = [int64]$size }
    } catch {}
  }
  Get-CimInstance Win32_VideoController | Where-Object { $_.PNPDeviceID -match "VEN_(1002|8086)" } | ForEach-Object {
    $bytes = if ($mem.ContainsKey($_.Name)) { $mem[$_.Name] } else { [int64]$_.AdapterRAM }
    $mib = [int]($bytes / 1MB)
    if ($mib -ge 4096) {
      $id = "PCI-" + (($_.PNPDeviceID -replace "^PCI\\", "") -replace "[^A-Za-z0-9]+", "-")
      $list += [pscustomobject]@{ name = $_.Name.Trim(); memoryMiB = $mib; uuid = $id; util = 0; temp = 0 }
    }
  }
  return $list
}

$gpus = @(Get-Gpus | ForEach-Object { @{ name = $_.name; memoryMiB = $_.memoryMiB; uuid = $_.uuid } })
if ($gpus.Count -eq 0) {
  Write-Host "No supported GPU found. Install the NVIDIA driver, the AMD driver, or Intel's xpu-smi tool, then run this again."
  exit 1
}
$body = @{
  code = $Code
  gpus = $gpus
  cpuCores = [int]$env:NUMBER_OF_PROCESSORS
  ramMiB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
}
try {
  $reply = Invoke-RestMethod -Method Post -Uri $Url -ContentType "application/json" -Body ($body | ConvertTo-Json -Depth 4)
  Write-Host "Verified. Go back to the website to finish your listing."
} catch {
  Write-Host "Verification failed: $($_.ErrorDetails.Message)"
}
