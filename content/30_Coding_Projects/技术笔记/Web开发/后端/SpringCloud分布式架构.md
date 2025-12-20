分布式：架构方式 分布部署在各个机器，集群：物理形态
微服务（自治）
分布式微服务的问题：
Remote Procedure Call RPC:HTTP+JSON远程调用，调用之前需要发现对方在哪
（注册中心、配置中心）
服务熔断->解决 服务雪崩（快速失败机制）
微服务：SpringBoot；注册中心/配置中心：Spring Cloud Alibaba Nacos;
网关：Spring Cloud Gateway；远程调用：Spring Cloud OpenFeign
服务熔断：Spring Cloud Alibaba Sentinel；分布式事务：Spring Cloud Alibaba Seata
