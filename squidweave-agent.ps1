# SQUIDWEAVE agent: reports this machine's status every 60 seconds.
$Key = "PASTE_YOUR_MACHINE_KEY"
$Url = "https://impressive-orca-501.convex.site/agent/heartbeat"

while ($true) {
  $body = @{ agentVersion = "ps-1.0" }
  if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    $stats = nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits |
      ForEach-Object { $p = $_ -split ","; [pscustomobject]@{ U = [double]$p[0]; T = [double]$p[1] } }
    if ($stats) {
      $body.utilization = ($stats | Measure-Object U -Average).Average
      $body.gpuTempC = ($stats | Measure-Object T -Maximum).Maximum
    }
  }
  try {
    Invoke-RestMethod -Method Post -Uri $Url -Headers @{ Authorization = "Bearer $Key" } `
      -ContentType "application/json" -Body ($body | ConvertTo-Json) | Out-Null
    Write-Host "$(Get-Date -Format T) heartbeat sent"
  } catch {
    Write-Host "$(Get-Date -Format T) heartbeat failed: $_"
  }
  Start-Sleep -Seconds 60
}
