# garden-stats.ps1
# YujiaMa's Garden Daily Stats
# Usage: Run .\garden-stats.ps1 in quartz directory

$ErrorActionPreference = "Continue"

function Write-Color {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

Write-Color "`nYujiaMa's Garden Daily Stats" "Green"
Write-Color "================================" "Green"

$today = Get-Date -Format "yyyy-MM-dd"
$todayDisplay = Get-Date -Format "MM.dd"

# 1. Calculate streak
Write-Color "`n[1/4] Calculating streak..." "Cyan"
$streak = 0
for ($i = 0; $i -lt 365; $i++) {
    $checkDate = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd")
    $commits = git log --since="$checkDate 00:00:00" --until="$checkDate 23:59:59" --oneline -- content/ 2>$null
    if ($commits) {
        $streak++
    } else {
        if ($i -eq 0) { continue }
        else { break }
    }
}
Write-Color "Current streak: $streak days" "Yellow"

# 2. Today's stats
Write-Color "`n[2/4] Today's updates..." "Cyan"

$todayCommits = git log --since="$today 00:00:00" --until="$today 23:59:59" --oneline -- content/ 2>$null
$totalFiles = 0
$insertions = 0
$deletions = 0

if ($todayCommits) {
    $firstCommit = (git log --since="$today 00:00:00" --until="$today 23:59:59" --reverse --format="%H" -- content/ | Select-Object -First 1)
    
    if ($firstCommit) {
        $diffOutput = git diff --stat "$firstCommit^..HEAD" -- content/ 2>$null
        
        if ($diffOutput) {
            $summaryLine = $diffOutput | Select-Object -Last 1
            
            if ($summaryLine -match '(\d+) file') { $totalFiles = [int]$matches[1] }
            if ($summaryLine -match '(\d+) insertion') { $insertions = [int]$matches[1] }
            if ($summaryLine -match '(\d+) deletion') { $deletions = [int]$matches[1] }
            
            Write-Color "   Files: $totalFiles" "White"
            Write-Color "   Added: +$insertions lines" "Green"
            Write-Color "   Deleted: -$deletions lines" "Red"
        }
    }
} else {
    Write-Color "   No commits today" "Gray"
}

# 3. Subject breakdown
Write-Color "`n[3/4] Subject breakdown..." "Cyan"

$subjectStats = @()
if ($todayCommits -and $firstCommit) {
    $subjects = @(
        @{pattern="*Network*"; name="Network"},
        @{pattern="*OS*"; name="OS"},
        @{pattern="*Math*"; name="Math"},
        @{pattern="*English*"; name="English"},
        @{pattern="*AI*"; name="AI"},
        @{pattern="*Parallel*"; name="Parallel"}
    )
    
    # Get all changed files
    $changedFiles = git diff --name-only "$firstCommit^..HEAD" -- content/ 2>$null
    
    if ($changedFiles) {
        # Count by folder
        $folderCounts = @{}
        foreach ($file in $changedFiles) {
            if ($file -match "content/([^/]+)/") {
                $folder = $matches[1]
                if (-not $folderCounts.ContainsKey($folder)) {
                    $folderCounts[$folder] = 0
                }
                $folderCounts[$folder]++
            }
        }
        
        foreach ($folder in $folderCounts.Keys | Sort-Object) {
            $count = $folderCounts[$folder]
            Write-Color "   $folder : $count files" "White"
            $subjectStats += "$folder($count)"
        }
    }
}

# 4. Generate changelog entry
Write-Color "`n[4/4] Changelog entry..." "Cyan"

if ($insertions -gt 0) {
    # Determine emoji
    if ($insertions -gt 1000) { $emoji = "[FIRE]" }
    elseif ($insertions -gt 500) { $emoji = "[BOOK]" }
    elseif ($insertions -gt 100) { $emoji = "[EDIT]" }
    else { $emoji = "[SEED]" }
    
    # Get updated file names
    $updatedFiles = git diff --name-only "$firstCommit^..HEAD" -- content/ 2>$null | 
        Where-Object { $_ -match "\.md$" } |
        ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) } |
        Where-Object { $_ -ne "CHANGELOG" -and $_ -notmatch "^\." } |
        Select-Object -First 4
    
    $noteNames = ($updatedFiles -join ", ")
    $noteCount = (git diff --name-only "$firstCommit^..HEAD" -- content/*.md 2>$null | Measure-Object).Count
    
    if ($noteCount -gt 4) {
        $noteNames = "$noteNames + $($noteCount - 4) more"
    }
    
    if (-not $noteNames) {
        $noteNames = "$totalFiles files"
    }
    
    $changelogEntry = "| $todayDisplay | $emoji $noteNames | +$insertions | $totalFiles |"
    
    Write-Color "`nToday's changelog entry:" "Green"
    Write-Color $changelogEntry "Yellow"
    
    # Copy to clipboard
    $changelogEntry | Set-Clipboard
    Write-Color "`nCopied to clipboard! Paste into CHANGELOG.md" "Green"
}

# 5. Summary
Write-Color "`n" "White"
Write-Color "========================================" "Green"
Write-Color "SUMMARY - $todayDisplay" "Green"
Write-Color "========================================" "Green"
Write-Color "Streak: $streak days" "Yellow"
if ($insertions -gt 0) {
    Write-Color "Today: +$insertions lines ($totalFiles files)" "White"
    if ($subjectStats.Count -gt 0) {
        Write-Color "Subjects: $($subjectStats -join ', ')" "White"
    }
} else {
    Write-Color "Today: No updates yet" "Gray"
}
Write-Color "========================================`n" "Green"

# 6. Ask to update CHANGELOG
if ($insertions -gt 0) {
    $response = Read-Host "Update CHANGELOG.md? (y/n)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        $changelogPath = "content/CHANGELOG.md"
        
        if (-not (Test-Path $changelogPath)) {
            Write-Color "Creating new CHANGELOG.md..." "Cyan"
            $newContent = @"
---
title: Changelog
---

# YujiaMa's Garden Changelog

> Daily learning progress | Target: PKU 2027

---

## Stats

**Streak**: $streak days

---

## Daily Log

| Date | Updates | Lines | Files |
| ---- | ------- | ----- | ----- |
$changelogEntry
"@
            $newContent | Out-File -FilePath $changelogPath -Encoding UTF8
        } else {
            $content = Get-Content $changelogPath -Raw -Encoding UTF8
            
            # Update streak
            $content = $content -replace '\*\*Streak\*\*: \d+ days', "**Streak**: $streak days"
            
            # Remove today's existing entry
            $content = $content -replace "\| $todayDisplay \|[^\r\n]+[\r\n]+", ""
            
            # Add new entry after table header
            $content = $content -replace '(\| ---- \| ------- \| ----- \| ----- \|)', "`$1`r`n$changelogEntry"
            
            $content | Out-File -FilePath $changelogPath -Encoding UTF8 -NoNewline
        }
        
        Write-Color "CHANGELOG.md updated!" "Green"
        Write-Color "Now run: git add . ; git commit -m 'update' ; git push" "Cyan"
    }
}