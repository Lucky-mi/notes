目标名称：依赖名
	(Tab)gcc -c main.c(编译命令)
伪目标：（.PHONY）
如clean：
		rm -f ……
		#清理临时文件
	all:
用$(变量名)来使用变量
$@:目标文件
$<:第一个依赖文件
$^:所有的依赖文件
make -n:打印出makefile要执行的命令，多用于调试