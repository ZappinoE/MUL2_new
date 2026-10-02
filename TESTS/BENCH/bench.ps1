param([string]$Exe,[string]$Case,[string]$RunDir,[string]$Threads='',[int]$TimeoutMin=30)
$ErrorActionPreference='Stop'
$o="C:\Program Files (x86)\Intel\oneAPI"
$env:PATH="$o\mkl\2025.0\bin;$o\compiler\2025.0\bin;$env:PATH"
if($Threads){$env:OMP_NUM_THREADS=$Threads; $env:MKL_NUM_THREADS=$Threads}
New-Item -ItemType Directory -Force $RunDir | Out-Null
foreach($d in 'REPORT','STATIC','DYNAMIC','WORK'){New-Item -ItemType Directory -Force "$RunDir\$d"|Out-Null}
Copy-Item "$Case\INPUT" "$RunDir\INPUT" -Recurse -Force
[IO.File]::WriteAllText("$RunDir\PATH_input.dat",'INPUT')
$sw=[Diagnostics.Stopwatch]::StartNew()
$p=Start-Process $Exe -WorkingDirectory $RunDir -RedirectStandardOutput "$RunDir\console.log" -RedirectStandardError "$RunDir\stderr.log" -PassThru -WindowStyle Hidden
$null=$p.Handle; $peak=0; $peakPriv=0
while(-not $p.HasExited){ $q=Get-Process -Id $p.Id -ErrorAction SilentlyContinue; if($q){ if($q.PeakWorkingSet64 -gt $peak){$peak=$q.PeakWorkingSet64}; if($q.PeakPagedMemorySize64 -gt $peakPriv){$peakPriv=$q.PeakPagedMemorySize64} }
  if($sw.Elapsed.TotalMinutes -gt $TimeoutMin){$p.Kill(); "TIMEOUT"; break}; Start-Sleep -Milliseconds 200 }
$p.WaitForExit(); $p.Refresh()
"{0}: exit={1} wall={2:N1}s cpu={3:N1}s peakWS={4:N2}GB peakCommit={5:N2}GB" -f (Split-Path $Exe -Leaf),$p.ExitCode,$sw.Elapsed.TotalSeconds,$p.TotalProcessorTime.TotalSeconds,($peak/1GB),($peakPriv/1GB)

