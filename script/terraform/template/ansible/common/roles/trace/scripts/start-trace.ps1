
param($roi,$itr)

function Is-ROI ($trace_module) {
  [string[]]$start_time = Get-Content -Path TRACE_START -ErrorAction SilentlyContinue

  while ($start_time.count -le $roi) {
    $start_time += "---"
  }

  $in_roi=$false
  if ((("${trace_module}:".Contains(":${roi}:")) -or ((-not ("${trace_module}:" -match ":[0-9]+:")) -and ("${roi}" -ne "0"))) -and ((("${trace_module}:".Contains(":itr${itr}:")) -or (-not ("${trace_module}:" -match ":itr[0-9]+:"))))) {
    if ($start_time[$roi] -eq "---") {
      $start_time[$roi] = Get-Date -Format "o"
      $in_roi=$true
    }
  } else {
    $start_time[$roi] = "---"
  }

  $start_time | Out-File -Force -Encoding utf8 -FilePath TRACE_START
  return $in_roi
}

Get-Job | Wait-Job

