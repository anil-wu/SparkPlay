#Requires -Version 5.1
<#
.SYNOPSIS
    项目仓库拉取脚本
    根据 repos.yaml 配置文件拉取或更新独立仓库

.DESCRIPTION
    该脚本读取 repos.yaml 配置文件，自动克隆或更新项目依赖的独立仓库

.EXAMPLE
    .\fetch-repos.ps1
    克隆或更新所有仓库

.EXAMPLE
    .\fetch-repos.ps1 -RepoName service
    仅克隆或更新名为 service 的仓库

.EXAMPLE
    .\fetch-repos.ps1 -Status
    查看所有仓库的状态
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepoName,

    [Parameter()]
    [switch]$Status,

    [Parameter()]
    [string]$ConfigFile = "../repos.yaml"
)

# 检查依赖
function Test-Dependencies {
    $deps = @("git")
    foreach ($dep in $deps) {
        if (!(Get-Command $dep -ErrorAction SilentlyContinue)) {
            Write-Error "未找到依赖: $dep，请确保已安装并添加到 PATH"
            exit 1
        }
    }

    # 检查是否有解析 YAML 的方法
    if (!(Get-Module -ListAvailable -Name "powershell-yaml")) {
        Write-Warning "建议安装 powershell-yaml 模块以获得更好的 YAML 解析体验"
        Write-Host "运行: Install-Module -Name powershell-yaml -Scope CurrentUser" -ForegroundColor Yellow
    }
}

# 简单的 YAML 解析函数（不依赖外部模块）
function Parse-YamlSimple {
    param([string]$YamlContent)

    $result = @{}
    $lines = $YamlContent -split "`r?`n"
    $currentRepo = $null
    $inRepos = $false
    $indentLevel = 0

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        # 跳过空行和注释
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }

        # 检测 repositories 部分开始
        if ($trimmed -eq "repositories:") {
            $inRepos = $true
            $result.repositories = @()
            continue
        }

        # 检测 global 部分
        if ($trimmed -eq "global:") {
            $inRepos = $false
            $result.global = @{}
            continue
        }

        # 解析 repositories 列表项
        if ($inRepos -and $line -match "^\s+-\s+name:\s*(.+)") {
            $currentRepo = @{
                name = $matches[1].Trim()
            }
            $result.repositories += $currentRepo
            continue
        }

        # 解析仓库属性
        if ($inRepos -and $currentRepo -and $line -match "^\s+(\w+):\s*(.*)") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            # 去除引号
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }

            # 转换布尔值
            if ($value -eq "true") { $value = $true }
            elseif ($value -eq "false") { $value = $false }
            elseif ($value -eq "null") { $value = $null }

            $currentRepo[$key] = $value
            continue
        }

        # 解析 global 属性
        if (!$inRepos -and $result.global -ne $null -and $line -match "^\s+(\w+):\s*(.*)") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }

            if ($value -eq "true") { $value = $true }
            elseif ($value -eq "false") { $value = $false }
            elseif ($value -eq "null") { $value = $null }

            $result.global[$key] = $value
        }
    }

    return $result
}

# 克隆或更新仓库
function Invoke-RepoSync {
    param(
        [hashtable]$Repo,
        [hashtable]$GlobalConfig
    )

    $name = $Repo.name
    $path = $Repo.path
    $url = $Repo.url
    $branch = $Repo.branch
    $depth = $Repo.depth

    # 使用全局默认值
    if ([string]::IsNullOrEmpty($depth)) {
        $depth = $GlobalConfig.default_depth
    }

    Write-Host "`n[$name]" -ForegroundColor Cyan
    Write-Host "  URL: $url" -ForegroundColor Gray
    Write-Host "  Path: $path" -ForegroundColor Gray
    Write-Host "  Branch: $branch" -ForegroundColor Gray

    # 检查目录是否已存在
    if (Test-Path $path) {
        Write-Host "  目录已存在，执行更新..." -ForegroundColor Yellow

        Push-Location $path
        try {
            # 检查是否是 git 仓库
            if (!(Test-Path ".git")) {
                Write-Warning "  $path 存在但不是 git 仓库，跳过"
                return
            }

            # 获取当前分支
            $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
            Write-Host "  当前分支: $currentBranch" -ForegroundColor Gray

            # 拉取更新
            Write-Host "  正在拉取更新..." -ForegroundColor Gray
            $output = git pull origin $branch 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  更新成功" -ForegroundColor Green
            } else {
                Write-Warning "  更新失败: $output"
            }

            # 如果需要切换到指定分支
            if ($branch -and $currentBranch -ne $branch) {
                Write-Host "  切换到分支: $branch" -ForegroundColor Gray
                git checkout $branch 2>&1 | Out-Null
            }
        }
        finally {
            Pop-Location
        }
    } else {
        Write-Host "  目录不存在，执行克隆..." -ForegroundColor Yellow

        # 构建克隆命令
        $cloneArgs = @("clone")

        if ($depth -and $depth -ne "null") {
            $cloneArgs += "--depth"
            $cloneArgs += $depth
        }

        if ($branch) {
            $cloneArgs += "--branch"
            $cloneArgs += $branch
        }

        if ($GlobalConfig.recursive -eq $true) {
            $cloneArgs += "--recursive"
        }

        $cloneArgs += $url
        $cloneArgs += $path

        Write-Host "  执行: git $([string]::Join(' ', $cloneArgs))" -ForegroundColor Gray

        $output = & git @cloneArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  克隆成功" -ForegroundColor Green
        } else {
            Write-Error "  克隆失败: $output"
        }
    }
}

# 查看仓库状态
function Show-RepoStatus {
    param([hashtable]$Repo)

    $name = $Repo.name
    $path = $Repo.path

    Write-Host "`n[$name]" -ForegroundColor Cyan

    if (!(Test-Path $path)) {
        Write-Host "  状态: " -NoNewline
        Write-Host "未克隆" -ForegroundColor Red
        return
    }

    Push-Location $path
    try {
        if (!(Test-Path ".git")) {
            Write-Host "  状态: " -NoNewline
            Write-Host "不是 git 仓库" -ForegroundColor Red
            return
        }

        $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
        $commitHash = git rev-parse --short HEAD 2>$null
        $remoteUrl = git remote get-url origin 2>$null

        # 检查是否有未提交的更改
        $status = git status --porcelain 2>$null
        $hasChanges = ![string]::IsNullOrEmpty($status)

        # 检查是否有未推送的提交
        $ahead = git rev-list --count "@{u}..HEAD" 2>$null
        $behind = git rev-list --count "HEAD..@{u}" 2>$null

        Write-Host "  状态: " -NoNewline
        if ($hasChanges) {
            Write-Host "有未提交更改" -ForegroundColor Yellow
        } else {
            Write-Host "干净" -ForegroundColor Green
        }

        Write-Host "  分支: $currentBranch"
        Write-Host "  Commit: $commitHash"
        Write-Host "  远程: $remoteUrl"

        if ($ahead -gt 0) {
            Write-Host "  领先远程: $ahead 个提交" -ForegroundColor Yellow
        }
        if ($behind -gt 0) {
            Write-Host "  落后远程: $behind 个提交" -ForegroundColor Yellow
        }
    }
    finally {
        Pop-Location
    }
}

# 主函数
function Main {
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "  项目仓库管理工具" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue

    # 检查依赖
    Test-Dependencies

    # 读取配置文件
    if (!(Test-Path $ConfigFile)) {
        Write-Error "配置文件不存在: $ConfigFile"
        exit 1
    }

    Write-Host "`n读取配置文件: $ConfigFile" -ForegroundColor Gray
    $yamlContent = Get-Content -Raw -Path $ConfigFile
    $config = Parse-YamlSimple -YamlContent $yamlContent

    if (!$config.repositories) {
        Write-Error "配置文件中未找到 repositories 部分"
        exit 1
    }

    Write-Host "发现 $($config.repositories.Count) 个仓库配置" -ForegroundColor Gray

    # 过滤仓库
    $reposToProcess = $config.repositories
    if ($RepoName) {
        $reposToProcess = $reposToProcess | Where-Object { $_.name -eq $RepoName }
        if ($reposToProcess.Count -eq 0) {
            Write-Error "未找到名为 '$RepoName' 的仓库配置"
            exit 1
        }
    }

    # 执行操作
    if ($Status) {
        foreach ($repo in $reposToProcess) {
            Show-RepoStatus -Repo $repo
        }
    } else {
        foreach ($repo in $reposToProcess) {
            Invoke-RepoSync -Repo $repo -GlobalConfig $config.global
        }
    }

    Write-Host "`n========================================" -ForegroundColor Blue
    Write-Host "  操作完成" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
}

# 执行主函数
Main
