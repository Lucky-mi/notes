# sync-notes.ps1
$source = "F:\Obsidian\笔记"
$dest = "D:\Quartz\quartz\content"

Write-Host "Source: $source"
Write-Host "Dest: $dest"

# 1. Delete old content
Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue

# 2. Copy files
Copy-Item -Path $source -Destination $dest -Recurse

# 3. Fix Z_Attachments junction
$subAttachments = Get-ChildItem -Path $dest -Directory -Recurse | Where-Object { $_.Name -eq "Z_Attachments" -and $_.FullName -ne "$dest\Z_Attachments" }
foreach ($folder in $subAttachments) {
    Remove-Item $folder.FullName -Recurse -Force
    cmd /c mklink /J $folder.FullName "$dest\Z_Attachments" | Out-Null
}

# 4. Done
$mdCount = (Get-ChildItem $dest -Recurse -Filter "*.md").Count
Write-Host "Done! $mdCount markdown files synced."
