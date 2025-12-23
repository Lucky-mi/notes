# garden-stats.ps1
# YujiaMa's Garden 每日统计脚本
# 使用方法: 在 quartz 目录下运行 .\garden-stats.ps1

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 颜色输出函数
function Write-Color {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

Write-Color "`n🌱 YujiaMa's Garden 每日统计" "Green"
Write-Color "================================" "Green"

$today = Get-Date -Format "yyyy-MM-dd"
$todayDisplay = Get-Date -Format "MM.dd"

# 1. 计算连续学习天数
Write-Color "`n📅 计算连续学习天数..." "Cyan"
$streak = 0
for ($i = 0; $i -lt 365; $i++) {
    $checkDate = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd")
    $commits = git log --since="$checkDate 00:00:00" --until="$checkDate 23:59:59" --oneline -- content/ 2>$null | Measure-Object -Line
    if ($commits.Lines -gt 0) {
        $streak++
    } else {
        if ($i -eq 0) { continue }
        else { break }
    }
}
Write-Color "🔥 当前连续: $streak 天" "Yellow"

# 2. 统计今日更新
Write-Color "`n📝 统计今日更新..." "Cyan"

$todayCommits = git log --since="$today 00:00:00" --until="$today 23:59:59" --oneline -- content/ 2>$null
if ($todayCommits) {
    $firstCommit = (git log --since="$today 00:00:00" --until="$today 23:59:59" --reverse --format="%H" -- content/ | Select-Object -First 1)
    
    try {
        $diffOutput = git diff --stat "$firstCommit^..HEAD" -- content/ 2>$null
    } catch {
        $diffOutput = git diff --stat HEAD -- content/ 2>$null
    }
    
    if ($diffOutput) {
        $summaryLine = $diffOutput | Select-Object -Last 1
        
        if ($summaryLine -match '(\d+) file') { $totalFiles = $matches[1] } else { $totalFiles = 0 }
        if ($summaryLine -match '(\d+) insertion') { $insertions = $matches[1] } else { $insertions = 0 }
        if ($summaryLine -match '(\d+) deletion') { $deletions = $matches[1] } else { $deletions = 0 }
        
        Write-Color "   📁 文件: $totalFiles" "White"
        Write-Color "   ➕ 新增: +$insertions 行" "Green"
        Write-Color "   ➖ 删除: -$deletions 行" "Red"
    }
} else {
    Write-Color "   今日暂无提交" "Gray"
    $totalFiles = 0
    $insertions = 0
    $deletions = 0
}

# 3. 分科目统计
Write-Color "`n📚 分科目统计..." "Cyan"

$subjects = @(
    @{path="content/10_CS_408/*网络*"; name="🌐 计网"},
    @{path="content/10_CS_408/*操作系统*"; name="💻 OS"},
    @{path="content/15_Classes/*并行*"; name="⚡ 并行"},
    @{path="content/12_Math"; name="📐 数学"},
    @{path="content/11_English"; name="🌏 英语"},
    @{path="content/20_AI-Research"; name="🧠 AI"}
)

$subjectStats = @()
foreach ($subject in $subjects) {
    if ($todayCommits -and $firstCommit) {
        $subjectDiff = git diff --stat "$firstCommit^..HEAD" -- $subject.path 2>$null | Select-Object -Last 1
        if ($subjectDiff -match '(\d+) insertion') {
            $lines = $matches[1]
            if ([int]$lines -gt 0) {
                Write-Color "   $($subject.name): +$lines" "White"
                $subjectStats += "$($subject.name) +$lines"
            }
        }
    }
}

# 4. 生成 CHANGELOG 条目
Write-Color "`n📋 生成更新记录..." "Cyan"

if ([int]$insertions -gt 0) {
    # 确定 emoji
    if ([int]$insertions -gt 1000) { $emoji = "🔥" }
    elseif ([int]$insertions -gt 500) { $emoji = "📚" }
    elseif ([int]$insertions -gt 100) { $emoji = "✏️" }
    else { $emoji = "🌱" }
    
    # 获取更新的文件名
    $updatedFiles = git diff --name-only "$firstCommit^..HEAD" -- content/*.md 2>$null | 
        ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) } |
        Where-Object { $_ -ne "CHANGELOG" -and $_ -notmatch "^\." } |
        Select-Object -First 4
    
    $noteNames = ($updatedFiles -join "、")
    $noteCount = (git diff --name-only "$firstCommit^..HEAD" -- content/*.md 2>$null | Measure-Object -Line).Lines
    
    if ($noteCount -gt 4) {
        $noteNames = "$noteNames 等${noteCount}篇"
    }
    
    if (-not $noteNames) {
        $noteNames = "${totalFiles}个文件"
    }
    
    $changelogEntry = "| $todayDisplay | $emoji $noteNames | +$insertions | $totalFiles |"
    
    Write-Color "`n✨ 今日更新记录:" "Green"
    Write-Color $changelogEntry "Yellow"
    
    # 复制到剪贴板
    $changelogEntry | Set-Clipboard
    Write-Color "`n📋 已复制到剪贴板！粘贴到 CHANGELOG.md 即可" "Green"
}

# 5. 生成完整的今日总结
Write-Color "`n" "White"
Write-Color "========================================" "Green"
Write-Color "📊 YujiaMa's Garden 今日总结 ($todayDisplay)" "Green"
Write-Color "========================================" "Green"
Write-Color "🔥 连续学习: $streak 天" "Yellow"
if ([int]$insertions -gt 0) {
    Write-Color "📝 今日更新: +$insertions 行 ($totalFiles 个文件)" "White"
    if ($subjectStats.Count -gt 0) {
        Write-Color "📚 科目分布: $($subjectStats -join ', ')" "White"
    }
} else {
    Write-Color "📝 今日暂无更新" "Gray"
}
Write-Color "========================================`n" "Green"

# 6. 询问是否自动更新 CHANGELOG
if ([int]$insertions -gt 0) {
    $response = Read-Host "是否自动更新 CHANGELOG.md? (y/n)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        $changelogPath = "content/CHANGELOG.md"
        
        if (-not (Test-Path $changelogPath)) {
            Write-Color "创建新的 CHANGELOG.md..." "Cyan"
            @"
---
title: 📝 更新日志
---

# YujiaMa's Garden 更新日志

> 🤖 记录每日学习进度 | 🎯 目标: PKU 软微 2027

---

## 📊 学习统计

🔥 **连续学习**: $streak 天

---

## 📅 每日记录

| 日期 | 更新内容 | 行数 | 文件 |
| ---- | -------- | ---- | ---- |
$changelogEntry
"@ | Out-File -FilePath $changelogPath -Encoding UTF8
        } else {
            # 读取现有文件
            $content = Get-Content $changelogPath -Raw -Encoding UTF8
            
            # 更新连续天数
            $content = $content -replace '🔥 \*\*连续学习\*\*: \d+ 天', "🔥 **连续学习**: $streak 天"
            
            # 删除今天已有的记录
            $content = $content -replace "\| $todayDisplay \|[^\n]+\n", ""
            
            # 在表头后插入新记录
            $content = $content -replace '(\| ---- \| -------- \| ---- \| ---- \|)', "`$1`n$changelogEntry"
            
            $content | Out-File -FilePath $changelogPath -Encoding UTF8 -NoNewline
        }
        
        Write-Color "✅ CHANGELOG.md 已更新!" "Green"
        Write-Color "现在可以运行: git add . && git commit -m 'update' && git push" "Cyan"
    }
}