# Run all generated example cases and print tip displacement / frequencies.
#   powershell DOC\BOOKS\examples\run_examples.ps1 -Cases <cases dir> -Exe <MUL2_V3.exe> -Out <run dir>
param(
  [string]$Cases,
  [string]$Exe = "$PSScriptRoot\..\..\..\BUILD\WINDOWS_IFX\Release\MUL2_V3.exe",
  [string]$Out = "$PSScriptRoot\runs"
)
$oneapi = "C:\Program Files (x86)\Intel\oneAPI"
$env:PATH = "$oneapi\mkl\2025.0\bin;$oneapi\compiler\2025.0\bin;$env:PATH"
foreach ($d in Get-ChildItem $Cases -Directory) {
  $run = Join-Path $Out $d.Name
  if (Test-Path $run) { [IO.Directory]::Delete($run, $true) }
  New-Item -ItemType Directory -Force $run | Out-Null
  foreach ($s in 'REPORT','STATIC','DYNAMIC','WORK') { New-Item -ItemType Directory -Force (Join-Path $run $s) | Out-Null }
  Copy-Item (Join-Path $d.FullName 'INPUT') (Join-Path $run 'INPUT') -Recurse -Force
  Push-Location $run
  & $Exe 'INPUT' > console.log 2> stderr.log
  Pop-Location
  $st = Join-Path $run 'STATIC\POST_POINT.dat'
  $fr = Join-Path $run 'DYNAMIC\FREQUENCIES.dat'
  if (Test-Path $st) {
    $row = @((Get-Content $st | Select-Object -Skip 1 -First 1) -split '\s+' | Where-Object { $_ })
    "{0}: tip displacement U = ({1}, {2}, {3})" -f $d.Name, $row[10], $row[11], $row[12]
  }
  if (Test-Path $fr) {
    "{0}: frequencies [Hz] = {1}" -f $d.Name, ((Get-Content $fr | ForEach-Object { ($_ -split ':')[1].Trim() }) -join '  ')
  }
}
