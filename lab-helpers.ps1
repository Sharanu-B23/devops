# lab-helpers.ps1 - load with:  . .\lab-helpers.ps1
$global:LabRoot    = if (Test-Path "D:\devops") { "D:\devops" } else { "D:\devops_aat-main" }
$global:JenkinsUrl = "http://localhost:8081"

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
}

# Runs a scriptblock, saves header + output + exit code to a UTF-8 log, returns {Code,Output,Log}
function Invoke-Logged {
    param(
        [Parameter(Mandatory)][string]$LogFile,
        [Parameter(Mandatory)][scriptblock]$Script
    )
    $full = if ([System.IO.Path]::IsPathRooted($LogFile)) { $LogFile } else { Join-Path $global:LabRoot $LogFile }
    $dir  = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $global:LASTEXITCODE = 0
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $lines = & $Script 2>&1 | ForEach-Object { "$_" }
    $code  = $LASTEXITCODE
    $ErrorActionPreference = $prev
    $text   = ($lines -join "`r`n")
    $header = "PS> " + $Script.ToString().Trim()
    Set-Content -Path $full -Value ($header + "`r`n" + $text + "`r`n[exit code: $code]") -Encoding UTF8
    Write-Host $text
    return [pscustomobject]@{ Code = $code; Output = $text; Log = $full }
}

function New-RandomSecret {
    param([int]$Length = 20)
    $chars = [char[]](48..57 + 65..90 + 97..122)
    -join (1..$Length | ForEach-Object { $chars | Get-Random })
}

function Get-EnvValue {
    param([string]$File, [string]$Key)
    $line = Get-Content $File | Where-Object { $_ -match "^$Key=" } | Select-Object -First 1
    if ($line) { return $line.Substring($Key.Length + 1) }
    return $null
}

function Test-PortFree {
    param([int]$Port)
    return -not (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

function Wait-Docker {
    param([int]$TimeoutSec = 180)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        docker info *> $null
        if ($LASTEXITCODE -eq 0) { return $true }
        Start-Sleep -Seconds 5
    }
    return $false
}

# Returns the response object when the URL returns the expected status, else $null
function Wait-Http {
    param([string]$Url, [int]$ExpectStatus = 200, [int]$TimeoutSec = 60)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
            if ($r.StatusCode -eq $ExpectStatus) { return $r }
        } catch { }
        Start-Sleep -Seconds 2
    }
    return $null
}

function Wait-Healthy {
    param([string]$Container, [int]$TimeoutSec = 120)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $s = docker inspect --format '{{.State.Health.Status}}' $Container 2>$null
        if ("$s" -eq "healthy") { return $true }
        Start-Sleep -Seconds 3
    }
    return $false
}

function Start-PortForward {
    param([string]$Context, [string]$Target, [int]$LocalPort, [int]$RemotePort, [string]$Namespace = "default")
    $mapping = "$($LocalPort):$($RemotePort)"
    $p = Start-Process -FilePath "kubectl" -ArgumentList @("--context", $Context, "-n", $Namespace, "port-forward", $Target, $mapping) -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 4
    return $p
}

function Stop-PortForward {
    param($Proc)
    if ($Proc -and -not $Proc.HasExited) { Stop-Process -Id $Proc.Id -Force }
}

function Wait-ReadyCount {
    param([string]$Context, [string]$Kind, [string]$Name, [int]$Want, [int]$TimeoutSec = 120)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $n = kubectl --context $Context get $Kind $Name -o jsonpath='{.status.readyReplicas}' 2>$null
        if ("$n" -eq "$Want") { return $true }
        Start-Sleep -Seconds 3
    }
    return $false
}

function Test-MinikubeRunning {
    param([string]$Profile)
    $s = minikube status -p $Profile --format '{{.Host}}' 2>$null
    return ("$s".Trim() -eq "Running")
}

# ---------- Jenkins helpers ----------
function Get-JenkinsHeaders {
    $u = if ($env:JENKINS_USER)  { $env:JENKINS_USER }  else { [Environment]::GetEnvironmentVariable("JENKINS_USER","User") }
    $t = if ($env:JENKINS_TOKEN) { $env:JENKINS_TOKEN } else { [Environment]::GetEnvironmentVariable("JENKINS_TOKEN","User") }
    if (-not $u -or -not $t) { return $null }
    $b = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($u):$($t)"))
    return @{ Authorization = "Basic $b" }
}

function Wait-Jenkins {
    param([int]$TimeoutSec = 240)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $r = Invoke-WebRequest "$global:JenkinsUrl/login" -UseBasicParsing -TimeoutSec 5
            if ($r.StatusCode -eq 200) { return $true }
        } catch {
            $resp = $_.Exception.Response
            if ($resp -and [int]$resp.StatusCode -ne 503) { return $true }
        }
        Start-Sleep -Seconds 5
    }
    return $false
}

function Get-JenkinsLastBuildNumber {
    param([string]$Job, $Headers)
    try { return [int](Invoke-RestMethod "$global:JenkinsUrl/job/$Job/lastBuild/api/json?tree=number" -Headers $Headers).number }
    catch { return 0 }
}

function Start-JenkinsBuild {
    param([string]$Job, $Headers)
    Invoke-WebRequest -Method Post "$global:JenkinsUrl/job/$Job/build" -Headers $Headers -UseBasicParsing | Out-Null
}

function Wait-JenkinsBuild {
    param([string]$Job, $Headers, [int]$After, [int]$TimeoutSec = 300)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $b = Invoke-RestMethod "$global:JenkinsUrl/job/$Job/lastBuild/api/json?tree=number,building,result" -Headers $Headers
            if ([int]$b.number -gt $After -and -not $b.building -and $b.result) { return $b }
        } catch { }
        Start-Sleep -Seconds 5
    }
    return $null
}

function Get-JenkinsConsole {
    param([string]$Job, [int]$Number, $Headers)
    return (Invoke-RestMethod "$global:JenkinsUrl/job/$Job/$Number/consoleText" -Headers $Headers)
}

# Creates the job, or updates it if it already exists
function Set-JenkinsJob {
    param([string]$Name, [string]$XmlPath, $Headers)
    $bytes = [Text.Encoding]::UTF8.GetBytes((Get-Content $XmlPath -Raw))
    $exists = $true
    try { Invoke-WebRequest "$global:JenkinsUrl/job/$Name/api/json" -Headers $Headers -UseBasicParsing | Out-Null } catch { $exists = $false }
    if ($exists) {
        Invoke-WebRequest -Method Post "$global:JenkinsUrl/job/$Name/config.xml" -Headers $Headers -ContentType "application/xml" -Body $bytes -UseBasicParsing | Out-Null
    } else {
        Invoke-WebRequest -Method Post "$global:JenkinsUrl/createItem?name=$Name" -Headers $Headers -ContentType "application/xml" -Body $bytes -UseBasicParsing | Out-Null
    }
}
