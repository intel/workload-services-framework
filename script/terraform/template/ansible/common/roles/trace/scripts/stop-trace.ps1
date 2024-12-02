
param($roi,$itr)

function Is-ROI ($trace_module) {
  [string[]]$stop_time = Get-Content -Path TRACE_STOP -ErrorAction SilentlyContinue

  while ($stop_time.count -le $roi) {
    $stop_time += "---"
  }

  $in_roi = $false
  if (((("${trace_module}:".Contains(":${roi}:")) -or ((-not ("${trace_module}:" -match ":[0-9]+:")) -and ("${roi}" -ne "0")))) -and ((("${trace_module}:".Contains(":itr${itr}:")) -or (-not ("${trace_module}:" -match ":itr[0-9]+:"))))) {
    if ($stop_time[$roi] -eq "---") {
      $stop_time[$roi] = Get-Date -Format "o"
      $in_roi = $true
    }
  } else {
    $stop_time[$roi] = "---"
  }

  $stop_time | Out-File -Force -Encoding utf8 -FilePath TRACE_STOP
  return $in_roi
}


Get-Job | Wait-Job
