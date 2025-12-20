### 1.1 
安装OpenBlas库：
```bash
git clone https://github.com/OpenMPI/OpenBLAS.git cd OpenBLAS # 编译安装 (使用所有核心) make -j$(nproc) USE_OPENMP=1 sudo make PREFIX=/usr/local/openblas install
```
下载并运行HPL源码：
```bash
wget https://www.netlib.org/benchmark/hpl/hpl-2.3.tar.gz
tar -xzf hpl-2.3.tar.gz
cd hpl-2.3
cd setup
```
查看可复制的模板：
![[{D549355A-9424-4E9B-A0F5-CA58103DC1BA}.png]]
```bash
# 复制一个模板 
cp Make.Linux_PII_CBLAS ../Make.linux64 
cd ..
```
