# SQUIDWEAVE agent: reports this machine's status every 60 seconds.
# Each report includes the GPU serial IDs so the marketplace can confirm the
# listed GPUs are the ones actually running.
$Key = "PASTE_YOUR_MACHINE_KEY"
$Url = "https://impressive-orca-501.convex.site/agent/heartbeat"

if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) {
  Write-Host "nvidia-smi not found. Install the NVIDIA driver, then run this again."
  exit 1
}

while ($true) {
  $stats = nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,uuid --format=csv,noheader,nounits |
    ForEach-Object {
      $p = $_ -split ",\s*"
      # Some cards report "[N/A]" for load or temperature
      $u = 0.0; $t = 0.0
      [void][double]::TryParse($p[0], [ref]$u); [void][double]::TryParse($p[1], [ref]$t)
      [pscustomobject]@{ U = $u; T = $t; Id = $p[2].Trim() }
    }
  $body = @{
    agentVersion = "ps-1.1"
    utilization = ($stats | Measure-Object U -Average).Average
    gpuTempC = ($stats | Measure-Object T -Maximum).Maximum
    gpuUuids = @($stats | ForEach-Object { $_.Id })
  }
  try {
    Invoke-RestMethod -Method Post -Uri $Url -Headers @{ Authorization = "Bearer $Key" } `
      -ContentType "application/json" -Body ($body | ConvertTo-Json) | Out-Null
    Write-Host "$(Get-Date -Format T) heartbeat sent"
  } catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 409) {
      Write-Host "$(Get-Date -Format T) hardware mismatch: these GPUs are not the ones verified for this listing. Run the hardware check again."
    } else {
      Write-Host "$(Get-Date -Format T) heartbeat failed: $_"
    }
  }
  Start-Sleep -Seconds 60
}
