Ingress配置域名
ConfigMap将配置信息与应用程序镜像内容分离开：应用程序与配置信息的解耦
Volumes：将持久化数据挂载到磁盘
StatefulSet状态应用单独部署
Node一个节点：如虚拟机
架构：Master-Worker架构
kubelet、k-proxy（负载均衡器
API server：所有请求都需要经过它，分发给相应组件
Scheduler：合理调度；Controller Manager:确保状态
minikube：本地单点搭建，搭建环境
kubectl：交互工具
