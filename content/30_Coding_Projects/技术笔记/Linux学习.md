Linux系统用虚拟文件系统接口将真文件系统与os分离，，掩盖文件系统的差异
看看哪个进程占了端口号并且杀掉：
```bash
netstat -ano | findstr :3000
taskkill /PID 34400 /F
```
这是端口占用的提示:
```bash
[nodemon] app crashed - waiting for file changes before starting...
```
内存模型：
平坦、不连续、稀疏
#### dd命令
用于读取、转换、输出命令
of=文件名：输出文件名，默认为标准输出。指定目标文件
if=文件名：输入文件名
count=blocks:仅拷贝blocks个块
ibs=bytes:一次读入bytes个字节
obs=bytes：输出bytes个字节
