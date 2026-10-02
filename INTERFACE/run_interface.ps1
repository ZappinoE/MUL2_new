param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 8765,
    [string]$Solver = '',
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$interfaceRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$projectRoot = [IO.Path]::GetFullPath((Join-Path $interfaceRoot '..'))
$runsRoot = Join-Path $interfaceRoot 'runs'

# The GUI only talks to the solver through files: INPUT/*.dat in, STATIC/DYNAMIC/REPORT out.
function Find-Solver {
    param([string]$Requested)
    $candidates = @()
    if ($Requested) { $candidates += $Requested }
    $candidates += (Join-Path $interfaceRoot 'MUL2_V3.exe')
    $candidates += (Join-Path $projectRoot 'BIN\MUL2_V3.exe')
    foreach ($config in 'Release', 'RelWithDebInfo', 'Debug') {
        $candidates += (Join-Path $projectRoot "BUILD\WINDOWS_IFX\$config\MUL2_V3.exe")
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return [IO.Path]::GetFullPath($candidate) }
    }
    return $null
}

$executable = Find-Solver $Solver
if ($null -eq $executable) {
    throw 'MUL2_V3.exe not found. Build it (CMake/Visual Studio) or pass -Solver <path>.'
}

# Make the MKL / Intel runtime DLLs visible when they are not next to the executable.
if (-not (Test-Path -LiteralPath (Join-Path (Split-Path $executable) 'libiomp5md.dll'))) {
    $roots = @($env:ONEAPI_ROOT, 'C:\Program Files (x86)\Intel\oneAPI') | Where-Object { $_ }
    foreach ($root in $roots) {
        foreach ($sub in 'compiler\latest\bin', 'mkl\latest\bin', 'compiler\2025.0\bin', 'mkl\2025.0\bin') {
            $dir = Join-Path $root $sub
            if (Test-Path -LiteralPath $dir -PathType Container) { $env:PATH = "$dir;$env:PATH" }
        }
    }
}
New-Item -ItemType Directory -Path $runsRoot -Force | Out-Null
$jobs = @{}

function Send-Bytes {
    param($Context, [byte[]]$Bytes, [string]$ContentType = 'application/octet-stream', [int]$StatusCode = 200)
    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = $ContentType
    $Context.Response.ContentLength64 = $Bytes.Length
    $Context.Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
    $Context.Response.OutputStream.Close()
}

function Send-Text {
    param($Context, [string]$Text, [string]$ContentType = 'text/plain; charset=utf-8', [int]$StatusCode = 200)
    Send-Bytes $Context ([Text.Encoding]::UTF8.GetBytes($Text)) $ContentType $StatusCode
}

function Send-Json {
    param($Context, $Value, [int]$StatusCode = 200)
    Send-Text $Context ($Value | ConvertTo-Json -Depth 8 -Compress) 'application/json; charset=utf-8' $StatusCode
}

function Get-ContentType {
    param([string]$Path)
    switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.html' { 'text/html; charset=utf-8' }
        '.css'  { 'text/css; charset=utf-8' }
        '.js'   { 'application/javascript; charset=utf-8' }
        '.json' { 'application/json; charset=utf-8' }
        '.vtk'  { 'text/plain; charset=utf-8' }
        '.dat'  { 'text/plain; charset=utf-8' }
        '.log'  { 'text/plain; charset=utf-8' }
        default { 'application/octet-stream' }
    }
}

function Test-ChildPath {
    param([string]$Root, [string]$Candidate)
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $candidateFull = [IO.Path]::GetFullPath($Candidate)
    return $candidateFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)
}

function Read-LogSafe {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    try { return [IO.File]::ReadAllText($Path) } catch { return '' }
}

function Get-JobView {
    param([string]$Id)
    if (-not $jobs.ContainsKey($Id)) { return $null }
    $job = $jobs[$Id]
    $job.Process.Refresh()
    $running = -not $job.Process.HasExited
    $status = if ($running) { 'running' } elseif ($job.Process.ExitCode -eq 0) { 'completed' } else { 'failed' }
    $results = @()
    if (-not $running) {
        foreach ($folderName in @('REPORT', 'STATIC', 'DYNAMIC')) {
            $folder = Join-Path $job.Directory $folderName
            if (-not (Test-Path -LiteralPath $folder -PathType Container)) { continue }
            foreach ($file in Get-ChildItem -LiteralPath $folder -File -Recurse) {
                $relative = $file.FullName.Substring($job.Directory.Length).TrimStart('\').Replace('\', '/')
                $url = '/api/file?id=' + [Uri]::EscapeDataString($Id) + '&path=' + [Uri]::EscapeDataString($relative)
                $results += [ordered]@{ name = $relative; size = $file.Length; url = $url }
            }
        }
    }
    return [ordered]@{
        id = $Id
        status = $status
        exitCode = if ($running) { $null } else { $job.Process.ExitCode }
        startedAt = $job.StartedAt.ToString('o')
        stdout = Read-LogSafe $job.Stdout
        stderr = Read-LogSafe $job.Stderr
        results = $results
    }
}

$listener = [Net.HttpListener]::new()
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host "MUL2 interface: $prefix"
Write-Host "Solver: $executable"
Write-Host 'Press Ctrl+C to stop.'

if (-not $NoBrowser) {
    Start-Process $prefix | Out-Null
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            $request = $context.Request
            $path = $request.Url.AbsolutePath

            if ($path -eq '/api/ping' -and $request.HttpMethod -eq 'GET') {
                Send-Json $context ([ordered]@{ ok = $true; executable = (Split-Path $executable -Leaf); version = 1 })
                continue
            }

            if ($path -eq '/api/run' -and $request.HttpMethod -eq 'POST') {
                $reader = [IO.StreamReader]::new($request.InputStream, $request.ContentEncoding)
                $payload = $reader.ReadToEnd() | ConvertFrom-Json
                $reader.Dispose()
                if ($null -eq $payload.files -or @($payload.files.PSObject.Properties).Count -eq 0) {
                    Send-Json $context @{ error = 'No input files supplied.' } 400
                    continue
                }

                $id = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
                $runDirectory = Join-Path $runsRoot $id
                $inputDirectory = Join-Path $runDirectory 'INPUT'
                New-Item -ItemType Directory -Path $runDirectory, $inputDirectory -Force | Out-Null
                New-Item -ItemType Directory -Path (Join-Path $runDirectory 'REPORT'), (Join-Path $runDirectory 'STATIC'), (Join-Path $runDirectory 'DYNAMIC'), (Join-Path $runDirectory 'WORK') -Force | Out-Null
                foreach ($property in $payload.files.PSObject.Properties) {
                    $name = [IO.Path]::GetFileName([string]$property.Name)
                    if ($name -ne $property.Name -or -not $name.EndsWith('.dat', [StringComparison]::OrdinalIgnoreCase)) { continue }
                    [IO.File]::WriteAllText((Join-Path $inputDirectory $name), [string]$property.Value, [Text.UTF8Encoding]::new($false))
                }
                [IO.File]::WriteAllText((Join-Path $runDirectory 'PATH_input.dat'), 'INPUT', [Text.ASCIIEncoding]::new())

                $stdout = Join-Path $runDirectory 'console.log'
                $stderr = Join-Path $runDirectory 'stderr.log'
                $process = Start-Process -FilePath $executable -WorkingDirectory $runDirectory -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
                $null = $process.Handle  # keep the handle so ExitCode stays readable
                $jobs[$id] = [ordered]@{ Process = $process; Directory = $runDirectory; Stdout = $stdout; Stderr = $stderr; StartedAt = Get-Date }
                Send-Json $context (Get-JobView $id) 202
                continue
            }

            if ($path -eq '/api/status' -and $request.HttpMethod -eq 'GET') {
                $id = $request.QueryString['id']
                $view = Get-JobView $id
                if ($null -eq $view) { Send-Json $context @{ error = 'Unknown run id.' } 404 } else { Send-Json $context $view }
                continue
            }

            if ($path -eq '/api/file' -and $request.HttpMethod -eq 'GET') {
                $id = $request.QueryString['id']
                $relative = $request.QueryString['path']
                if (-not $jobs.ContainsKey($id)) { Send-Json $context @{ error = 'Unknown run id.' } 404; continue }
                $jobRoot = $jobs[$id].Directory
                $candidate = Join-Path $jobRoot ($relative.Replace('/', '\'))
                if (-not (Test-ChildPath $jobRoot $candidate) -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                    Send-Json $context @{ error = 'Result file not found.' } 404
                    continue
                }
                Send-Bytes $context ([IO.File]::ReadAllBytes($candidate)) (Get-ContentType $candidate)
                continue
            }

            if ($request.HttpMethod -ne 'GET') { Send-Text $context 'Method not allowed' 'text/plain' 405; continue }
            $relativePath = if ($path -eq '/') { 'index.html' } else { [Uri]::UnescapeDataString($path.TrimStart('/')).Replace('/', '\') }
            $staticPath = Join-Path $interfaceRoot $relativePath
            if (-not (Test-ChildPath $interfaceRoot $staticPath) -or -not (Test-Path -LiteralPath $staticPath -PathType Leaf)) {
                Send-Text $context 'Not found' 'text/plain' 404
                continue
            }
            Send-Bytes $context ([IO.File]::ReadAllBytes($staticPath)) (Get-ContentType $staticPath)
        } catch {
            try { Send-Json $context @{ error = $_.Exception.Message } 500 } catch { }
        }
    }
} finally {
    $listener.Stop()
    $listener.Close()
}