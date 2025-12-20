@echo off
chcp 65001
echo ==========================================
echo 正在把 [整个笔记库] 搬运到 Quartz...
echo ==========================================

:: 核心命令：把 F:\Obsidian\笔记 镜像复制到 content
:: /MIR = 镜像 (源文件删了，这里也会删)
:: /XD = 排除文件夹 (防止递归复制或不需要的文件夹)
robocopy "F:\Obsidian\笔记" "D:\Quartz\quartz\content" /MIR /XD ".git" ".obsidian" ".trash"

echo.
echo ==========================================
echo 正在构建并推送到 GitHub...
echo ==========================================
call npx quartz sync
pause