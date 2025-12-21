| 操作           | 比喻       | 发生在哪里 | 意义                            |
| ------------ | -------- | ----- | ----------------------------- |
| `git add`    | 把内容写进草稿纸 | 本地    | 暂时准备提交的内容                     |
| `git commit` | 把草稿存进日记本 | 本地    | 形成一条提交记录（commit）              |
| `git push`   | 把日记拍照发微博 | 远程    | 把本地的 commit 同步到 GitLab/GitHub |
终于成功提交了
先配置一下： 
git config --global user.email "yujiama050421@gmail.com“
git config --global user.name "bnu-202311081040"
git add .
git commit -m "update"
git push origin master  //提交了，完美
再拉取更新内容：
git pull origin master