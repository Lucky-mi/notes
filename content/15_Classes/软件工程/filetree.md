# 校园二手交易平台 - 项目文件结构

## 整体项目结构

```
campus-trading-platform/
├── README.md
├── docker-compose.yml
├── .gitignore
├── .env.example
│
├── frontend/                          # 前端项目
│   ├── web/                          # Web端 (Vue 3)
│   │   ├── public/
│   │   ├── src/
│   │   │   ├── components/           # 公共组件
│   │   │   │   ├── common/
│   │   │   │   │   ├── Header.vue
│   │   │   │   │   ├── Footer.vue
│   │   │   │   │   ├── Loading.vue
│   │   │   │   │   └── Pagination.vue
│   │   │   │   ├── product/
│   │   │   │   │   ├── ProductCard.vue
│   │   │   │   │   ├── ProductList.vue
│   │   │   │   │   ├── ProductDetail.vue
│   │   │   │   │   └── ProductForm.vue
│   │   │   │   ├── user/
│   │   │   │   │   ├── UserProfile.vue
│   │   │   │   │   ├── LoginForm.vue
│   │   │   │   │   └── RegisterForm.vue
│   │   │   │   └── transaction/
│   │   │   │       ├── ChatWindow.vue
│   │   │   │       ├── OrderCard.vue
│   │   │   │       └── ReviewForm.vue
│   │   │   ├── views/                # 页面组件
│   │   │   │   ├── Home.vue
│   │   │   │   ├── ProductList.vue
│   │   │   │   ├── ProductDetail.vue
│   │   │   │   ├── PublishProduct.vue
│   │   │   │   ├── UserCenter.vue
│   │   │   │   ├── Messages.vue
│   │   │   │   ├── Orders.vue
│   │   │   │   ├── Login.vue
│   │   │   │   └── Register.vue
│   │   │   ├── router/               # 路由配置
│   │   │   │   └── index.ts
│   │   │   ├── store/                # 状态管理
│   │   │   │   ├── modules/
│   │   │   │   │   ├── user.ts
│   │   │   │   │   ├── product.ts
│   │   │   │   │   └── transaction.ts
│   │   │   │   └── index.ts
│   │   │   ├── api/                  # API接口
│   │   │   │   ├── user.ts
│   │   │   │   ├── product.ts
│   │   │   │   ├── transaction.ts
│   │   │   │   └── upload.ts
│   │   │   ├── utils/                # 工具函数
│   │   │   │   ├── request.ts
│   │   │   │   ├── auth.ts
│   │   │   │   ├── format.ts
│   │   │   │   └── validation.ts
│   │   │   ├── assets/               # 静态资源
│   │   │   │   ├── images/
│   │   │   │   ├── icons/
│   │   │   │   └── styles/
│   │   │   ├── App.vue
│   │   │   └── main.ts
│   │   ├── package.json
│   │   ├── vite.config.ts
│   │   └── tsconfig.json
│   │
│   ├── mobile/                       # 移动端 (Vue 3 + Vant)
│   │   ├── public/
│   │   ├── src/
│   │   │   ├── components/           # 移动端组件
│   │   │   ├── views/                # 移动端页面
│   │   │   ├── router/
│   │   │   ├── store/
│   │   │   ├── api/
│   │   │   └── utils/
│   │   ├── package.json
│   │   └── vite.config.ts
│   │
│   └── admin/                        # 管理后台 (Vue 3 + Element Plus)
│       ├── public/
│       ├── src/
│       │   ├── components/
│       │   ├── views/
│       │   │   ├── Dashboard.vue
│       │   │   ├── UserManagement.vue
│       │   │   ├── ProductManagement.vue
│       │   │   ├── TransactionManagement.vue
│       │   │   ├── ReportManagement.vue
│       │   │   └── Analytics.vue
│       │   ├── router/
│       │   ├── store/
│       │   └── api/
│       ├── package.json
│       └── vite.config.ts
│
├── backend/                          # 后端项目
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                   # FastAPI应用入口
│   │   ├── config.py                 # 配置文件
│   │   ├── database.py               # 数据库连接
│   │   ├── dependencies.py           # 依赖注入
│   │   │
│   │   ├── models/                   # 数据模型
│   │   │   ├── __init__.py
│   │   │   ├── user.py
│   │   │   ├── product.py
│   │   │   ├── transaction.py
│   │   │   ├── message.py
│   │   │   ├── review.py
│   │   │   └── report.py
│   │   │
│   │   ├── schemas/                  # Pydantic模式
│   │   │   ├── __init__.py
│   │   │   ├── user.py
│   │   │   ├── product.py
│   │   │   ├── transaction.py
│   │   │   ├── message.py
│   │   │   └── common.py
│   │   │
│   │   ├── api/                      # API路由
│   │   │   ├── __init__.py
│   │   │   ├── deps.py               # API依赖
│   │   │   ├── v1/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── auth.py           # 认证相关
│   │   │   │   ├── users.py          # 用户管理
│   │   │   │   ├── products.py       # 商品管理
│   │   │   │   ├── transactions.py   # 交易管理
│   │   │   │   ├── messages.py       # 消息管理
│   │   │   │   ├── reviews.py        # 评价管理
│   │   │   │   ├── upload.py         # 文件上传
│   │   │   │   └── admin.py          # 管理接口
│   │   │   └── api.py                # API路由汇总
│   │   │
│   │   ├── services/                 # 业务逻辑层
│   │   │   ├── __init__.py
│   │   │   ├── user_service.py
│   │   │   ├── product_service.py
│   │   │   ├── transaction_service.py
│   │   │   ├── message_service.py
│   │   │   ├── search_service.py
│   │   │   ├── notification_service.py
│   │   │   └── file_service.py
│   │   │
│   │   ├── core/                     # 核心功能
│   │   │   ├── __init__.py
│   │   │   ├── auth.py               # 认证逻辑
│   │   │   ├── security.py           # 安全相关
│   │   │   ├── cache.py              # 缓存操作
│   │   │   ├── search.py             # 搜索引擎
│   │   │   └── websocket.py          # WebSocket连接
│   │   │
│   │   ├── utils/                    # 工具函数
│   │   │   ├── __init__.py
│   │   │   ├── common.py
│   │   │   ├── validators.py
│   │   │   ├── formatters.py
│   │   │   └── exceptions.py
│   │   │
│   │   └── tests/                    # 测试文件
│   │       ├── __init__.py
│   │       ├── conftest.py
│   │       ├── test_auth.py
│   │       ├── test_users.py
│   │       ├── test_products.py
│   │       └── test_transactions.py
│   │
│   ├── alembic/                      # 数据库迁移
│   │   ├── versions/
│   │   ├── env.py
│   │   └── alembic.ini
│   │
│   ├── requirements.txt              # Python依赖
│   ├── Dockerfile
│   └── .env.example
│
├── infrastructure/                   # 基础设施配置
│   ├── docker/
│   │   ├── nginx/
│   │   │   ├── nginx.conf
│   │   │   └── Dockerfile
│   │   ├── postgres/
│   │   │   ├── init.sql
│   │   │   └── Dockerfile
│   │   └── redis/
│   │       └── redis.conf
│   │
│   ├── k8s/                         # Kubernetes配置
│   │   ├── namespace.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── ingress.yaml
│   │
│   └── monitoring/                  # 监控配置
│       ├── prometheus/
│       │   └── prometheus.yml
│       ├── grafana/
│       │   └── dashboards/
│       └── alertmanager/
│           └── alertmanager.yml
│
├── scripts/                         # 部署和运维脚本
│   ├── deploy.sh                    # 部署脚本
│   ├── backup.sh                    # 数据备份脚本
│   ├── init-db.sh                   # 数据库初始化
│   └── health-check.sh              # 健康检查脚本
│
└── docs/                           # 项目文档
    ├── api/                        # API文档
    │   ├── openapi.json
    │   └── README.md
    ├── deployment/                 # 部署文档
    │   ├── local-setup.md
    │   ├── production-deploy.md
    │   └── monitoring-setup.md
    ├── development/                # 开发文档
    │   ├── coding-standards.md
    │   ├── git-workflow.md
    │   └── testing-guide.md
    └── user/                       # 用户文档
        ├── user-manual.md
        └── admin-manual.md
```

## 关键文件说明

### 前端关键文件

1. **`frontend/web/src/main.ts`** - Vue应用入口文件
2. **`frontend/web/src/router/index.ts`** - 路由配置
3. **`frontend/web/src/store/index.ts`** - Pinia状态管理配置
4. **`frontend/web/src/api/`** - API接口封装
5. **`frontend/web/src/utils/request.ts`** - HTTP请求封装

### 后端关键文件

1. **`backend/app/main.py`** - FastAPI应用入口
2. **`backend/app/config.py`** - 应用配置
3. **`backend/app/database.py`** - 数据库连接配置
4. **`backend/app/models/`** - SQLModel数据模型
5. **`backend/app/api/v1/`** - API路由定义
6. **`backend/app/services/`** - 业务逻辑实现

### 基础设施关键文件

1. **`docker-compose.yml`** - 本地开发环境配置
2. **`infrastructure/k8s/`** - Kubernetes部署配置
3. **`infrastructure/nginx/nginx.conf`** - Nginx配置
4. **`scripts/deploy.sh`** - 自动化部署脚本

### 配置文件

1. **`.env.example`** - 环境变量模板
2. **`backend/requirements.txt`** - Python依赖
3. **`frontend/*/package.json`** - Node.js依赖
4. **`alembic.ini`** - 数据库迁移配置

## 开发工作流

1. **本地开发**：使用docker-compose启动开发环境
2. **代码提交**：遵循Git工作流规范
3. **测试验证**：运行单元测试和集成测试
4. **部署上线**：通过CI/CD流水线自动部署

这个文件结构为校园二手交易平台提供了清晰的组织架构，便于团队协作开发和后期维护。