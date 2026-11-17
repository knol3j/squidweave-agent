# SQUIDWEAVE hardware check: reads this machine's GPUs, CPU and RAM once and sends them for verification.
$Code = "PASTE_YOUR_SCAN_CODE"
$Url = "https://impressive-orca-501.convex.site/agent/scan"

if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) {
  Write-Host "nvidia-smi not found. Install the NVIDIA driver, then run this again."
  exit 1
}
$gpus = @(nvidia-smi --query-gpu=name,memory.total,uuid --format=csv,noheader,nounits | ForEach-Object {
  $p = $_ -split ",\s*"
  @{ name = $p[0].Trim(); memoryMiB = [int]$p[1]; uuid = $p[2].Trim() }
})
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
