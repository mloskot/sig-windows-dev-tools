Set-StrictMode -Version Latest

Write-Host "[swdt.ps1] $args"

if (-not (Test-Path -Path (Join-Path -Path (Get-Location) -ChildPath "go.work"))) {
  & go work init .
  #& go mod tidy
}

$startAt = (Get-Date)
if ($args[0] -eq "test") {
  & go test -v ./...
} else {
  & go run -buildvcs=true ./main.go $args | Out-Default
}
$runTime = (Get-Date) - $startAt

if ($global:LASTEXITCODE -gt 0) {
  $success = "non-success"
} else {
  $success = "success"
}
Write-Host ("[swdt.ps1] Run in {0:00}:{1:00}:{2:00} and exited with {3} code" `
  -f $runTime.Hours, $runTime.Minutes, $runTime.Seconds, $success)
