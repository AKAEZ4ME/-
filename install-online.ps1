#Requires -Version 5.1
<#
  dsh-boot-suite —— 在线一键安装（AKAEZ4ME/-）
  用法（PowerShell 里执行一行）：
    irm https://raw.githubusercontent.com/AKAEZ4ME/-/main/install-online.ps1 | iex
#>
[CmdletBinding()]
param(
  [string]$Version = '',
  [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
$repo = 'AKAEZ4ME/-'
$fallbackVersion = '2.13.22'

function Say($m) { Write-Host $m }
function Die($m) { Write-Host ('[x] ' + $m) -ForegroundColor Red; exit 1 }

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  dsh-boot-suite —— 在线安装（AKAEZ4ME/-）' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  [重要] 请先完全退出 DeepSeek Harness Desktop（右下角托盘也要退出）'
Write-Host ''

# PowerShell 5.1 默认可能还是 TLS 1.0；GitHub 需要 TLS 1.2+
try {
  $Tls12 = [Net.SecurityProtocolType]::Tls12
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $Tls12
} catch {
  # 旧系统不支持就交给系统默认
}

$ver = $Version.Trim().TrimStart('v')
if (-not $ver) {
  try {
    $rel = Invoke-RestMethod -Uri ('https://api.github.com/repos/' + $repo + '/releases/latest') `
      -Headers @{ 'User-Agent' = 'dsh-boot-suite-installer' } -UseBasicParsing -TimeoutSec 30
    $ver = ([string]$rel.tag_name).Trim().TrimStart('v')
    if (-not $ver) { throw 'release 里没有 tag_name' }
  } catch {
    Write-Host ('[!] 读取最新版本失败：' + $_.Exception.Message)
    Write-Host ('    改用固定版本 v' + $fallbackVersion)
    $ver = $fallbackVersion
  }
}

$zipName = 'dsh-boot-suite-win-V' + $ver + '.zip'
$zipUrl = 'https://github.com/' + $repo + '/releases/download/v' + $ver + '/' + $zipName
$tmp = Join-Path $env:TEMP ('dsh-boot-suite-online-' + $ver + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = Join-Path $tmp $zipName
$dir = Join-Path $tmp 'pkg'

Say ('[1/3] 下载 v' + $ver + '…')
try {
  Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing -TimeoutSec 300
} catch {
  Die ('下载失败：' + $_.Exception.Message + '（请检查网络/代理后重试）')
}
if (-not (Test-Path $zip) -or (Get-Item $zip).Length -lt 1024 * 1024) {
  Die '下载的安装包不完整（小于 1MB），请重试'
}

Say '[2/3] 解压…'
Expand-Archive -Path $zip -DestinationPath $dir -Force

$installPs1 = Get-ChildItem $dir -Recurse -Filter 'install.ps1' -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match '[/\\]tools[/\\]install\.ps1$' } |
  Select-Object -First 1
if (-not $installPs1) {
  Die '压缩包里没找到 tools\install.ps1，可能下载不完整'
}

Say '[3/3] 启动安装器…'
if ($CheckOnly) {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installPs1.FullName -CheckOnly
} else {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installPs1.FullName
}

Say ''
Say ('临时目录：' + $tmp)
Say '安装结束。如果失败，请运行解压目录里的「诊断.cmd」并把桌面生成的报告发给作者。'
