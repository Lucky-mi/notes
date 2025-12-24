# 校园二手交易平台 - 系统设计文档

## 1. 实施方案

### 1.1 架构设计原则

基于校园二手交易平台的特点，我们采用以下设计原则：

1. **微服务架构**：将系统拆分为独立的服务模块，提高可维护性和扩展性
2. **分层架构**：采用经典的三层架构模式，职责分离清晰
3. **高可用设计**：考虑毕业季高并发场景，设计负载均衡和缓存策略
4. **安全优先**：校园封闭环境下的身份认证和数据安全保护
5. **移动优先**：针对学生用户习惯，优先考虑移动端体验

### 1.2 技术栈选择

#### 前端技术栈
- **Vue 3 + TypeScript**：现代化的前端框架，提供良好的开发体验
- **Element Plus**：成熟的UI组件库，快速构建管理后台
- **Vant**：移动端UI组件库，适配手机端用户
- **Pinia**：状态管理，替代Vuex的现代化方案
- **Vite**：快速的构建工具

#### 后端技术栈
- **FastAPI + Python**：高性能异步框架，开发效率高，适合快速迭代
- **SQLModel**：基于Pydantic和SQLAlchemy的ORM，类型安全
- **Redis**：缓存和会话存储，提高系统性能
- **PostgreSQL**：主数据库，支持复杂查询和事务
- **Elasticsearch**：商品搜索引擎，提供全文检索能力
- **RabbitMQ**：消息队列，处理异步任务

#### 基础设施
- **Docker + Kubernetes**：容器化部署，便于扩展和管理
- **Nginx**：反向代理和负载均衡
- **MinIO**：对象存储，处理图片和文件
- **Prometheus + Grafana**：监控和告警系统

### 1.3 关键技术决策

1. **选择FastAPI的原因**：
   - 高性能：基于Starlette和Pydantic，性能优异
   - 类型安全：原生支持Python类型提示
   - 自动文档：自动生成OpenAPI文档
   - 异步支持：原生支持async/await

2. **选择PostgreSQL的原因**：
   - 事务支持：确保交易数据一致性
   - 复杂查询：支持复杂的商品筛选和统计
   - JSON支持：灵活存储商品属性
   - 扩展性：支持读写分离和分库分表

3. **选择Elasticsearch的原因**：
   - 全文检索：支持中文分词和模糊搜索
   - 实时索引：商品发布后即时可搜索
   - 聚合分析：支持分类统计和价格分析

## 2. 主要用户-UI交互模式

### 2.1 核心交互场景

1. **商品发布流程**
   - 用户登录 → 选择发布 → 拍照上传 → 填写信息 → 设置价格 → 发布成功
   - 关键交互：拖拽上传图片、智能价格建议、分类选择器

2. **商品搜索浏览**
   - 首页浏览 → 关键词搜索 → 筛选条件 → 查看详情 → 收藏/联系
   - 关键交互：搜索建议、筛选面板、无限滚动加载

3. **沟通议价流程**
   - 点击联系 → 即时聊天 → 发起议价 → 协商价格 → 确认交易
   - 关键交互：实时聊天界面、议价组件、位置选择

4. **交易完成流程**
   - 线下见面 → 确认商品 → 完成交易 → 互相评价
   - 关键交互：交易确认按钮、评价星级、评价文本

### 2.2 特色功能交互

1. **新生专区**：专门的新生商品推荐区域，简化选择流程
2. **毕业季专区**：批量发布界面，支持快速处理大量物品
3. **校园地图**：集成校园地图，选择交易地点
4. **身份认证**：学生证拍照认证，确保用户真实性

## 3. 数据结构和接口概览

### 3.1 核心数据模型

```python
# 用户模型
class User(SQLModel, table=True):
    user_id: UUID = Field(primary_key=True)
    student_id: str = Field(unique=True, index=True)
    username: str
    email: str
    phone: str
    school: str
    college: str
    grade: int
    credit_score: float = Field(default=100.0)
    status: UserStatus = Field(default=UserStatus.ACTIVE)
    created_at: datetime
    updated_at: datetime

# 商品模型
class Product(SQLModel, table=True):
    product_id: UUID = Field(primary_key=True)
    seller_id: UUID = Field(foreign_key="user.user_id")
    title: str = Field(max_length=100)
    description: str
    price: Decimal = Field(decimal_places=2)
    category_id: UUID = Field(foreign_key="category.category_id")
    condition: ProductCondition
    status: ProductStatus = Field(default=ProductStatus.PUBLISHED)
    location: str
    images: List[str] = Field(sa_column=Column(JSON))
    view_count: int = Field(default=0)
    created_at: datetime
    updated_at: datetime

# 交易模型
class Transaction(SQLModel, table=True):
    transaction_id: UUID = Field(primary_key=True)
    product_id: UUID = Field(foreign_key="product.product_id")
    buyer_id: UUID = Field(foreign_key="user.user_id")
    seller_id: UUID = Field(foreign_key="user.user_id")
    price: Decimal = Field(decimal_places=2)
    status: TransactionStatus = Field(default=TransactionStatus.PENDING)
    meeting_location: str
    meeting_time: datetime
    created_at: datetime
    completed_at: Optional[datetime]
```

### 3.2 核心API接口

```python
# 用户认证接口
@router.post("/auth/login")
async def login(credentials: LoginRequest) -> TokenResponse:
    """用户登录接口"""
    pass

@router.post("/auth/register")
async def register(user_data: RegisterRequest) -> UserResponse:
    """用户注册接口"""
    pass

# 商品管理接口
@router.post("/products")
async def create_product(product: ProductCreateRequest) -> ProductResponse:
    """发布商品接口"""
    pass

@router.get("/products/search")
async def search_products(
    keyword: str = None,
    category_id: UUID = None,
    min_price: float = None,
    max_price: float = None,
    page: int = 1,
    size: int = 20
) -> ProductListResponse:
    """搜索商品接口"""
    pass

# 交易管理接口
@router.post("/transactions")
async def create_transaction(transaction: TransactionCreateRequest) -> TransactionResponse:
    """创建交易接口"""
    pass

@router.put("/transactions/{transaction_id}/complete")
async def complete_transaction(transaction_id: UUID) -> TransactionResponse:
    """完成交易接口"""
    pass
```

## 4. 程序调用流程概览

### 4.1 商品发布流程

1. **用户认证**：验证JWT Token，获取用户信息
2. **图片上传**：调用文件服务，上传商品图片到MinIO
3. **商品创建**：保存商品信息到PostgreSQL
4. **搜索索引**：异步更新Elasticsearch索引
5. **缓存更新**：更新Redis中的热门商品缓存
6. **通知推送**：通过消息队列发送新品上架通知

### 4.2 商品搜索流程

1. **缓存检查**：首先检查Redis中的搜索结果缓存
2. **搜索执行**：调用Elasticsearch执行全文搜索
3. **数据补充**：从PostgreSQL获取完整的商品信息
4. **结果缓存**：将搜索结果缓存到Redis
5. **日志记录**：记录搜索行为用于推荐算法

### 4.3 交易处理流程

1. **订单创建**：在PostgreSQL中创建交易记录
2. **状态同步**：更新商品状态为"交易中"
3. **消息通知**：通过WebSocket实时通知买卖双方
4. **支付处理**：集成第三方支付接口（如支付宝）
5. **交易完成**：更新交易状态，触发评价流程

## 5. 数据库ER图概览

### 5.1 核心实体关系

- **用户(User)** ←→ **商品(Product)**：一对多关系，一个用户可以发布多个商品
- **用户(User)** ←→ **交易(Transaction)**：多对多关系，用户可以作为买家或卖家参与多个交易
- **商品(Product)** ←→ **交易(Transaction)**：一对多关系，一个商品可以有多次交易记录
- **交易(Transaction)** ←→ **评价(Review)**：一对二关系，每个交易有买家和卖家的双向评价
- **用户(User)** ←→ **消息(Message)**：一对多关系，用户可以发送和接收多条消息

### 5.2 数据库设计要点

1. **分库分表策略**：按学校或地区分库，按时间分表
2. **索引优化**：为搜索字段和外键建立合适的索引
3. **数据归档**：定期归档历史交易数据
4. **备份策略**：主从复制 + 定时备份

## 6. 不明确的方面

### 6.1 业务规则待确认

1. **交易担保机制**：是否需要平台担保交易，如何处理纠纷？
2. **手续费策略**：平台是否收取交易手续费，费率如何设定？
3. **商品审核流程**：是否需要人工审核，审核标准是什么？
4. **用户等级制度**：如何设计用户信誉等级和权限？

### 6.2 技术实现待确认

1. **支付集成**：具体集成哪些支付方式，是否支持校园卡？
2. **推送服务**：使用哪种推送服务，如何处理iOS和Android差异？
3. **图片处理**：是否需要图片压缩和水印功能？
4. **数据分析**：需要哪些具体的数据统计和分析功能？

### 6.3 运营策略待确认

1. **多校区部署**：如何支持多个学校，数据是否隔离？
2. **内容监管**：如何识别和处理违规内容？
3. **用户增长**：如何设计邀请机制和激励体系？
4. **客服系统**：是否需要在线客服功能？

## 7. 部署和运维

### 7.1 部署架构

```
Internet
    ↓
[负载均衡器 Nginx]
    ↓
[API网关 Kong/Traefik]
    ↓
[Kubernetes集群]
    ├── [前端服务 Pod]
    ├── [后端服务 Pod]
    ├── [数据库 StatefulSet]
    ├── [Redis集群]
    └── [Elasticsearch集群]
```

### 7.2 监控和告警

- **应用监控**：使用Prometheus收集应用指标
- **日志监控**：使用ELK Stack收集和分析日志
- **性能监控**：使用APM工具监控接口性能
- **告警机制**：设置关键指标告警，及时发现问题

这个系统设计为校园二手交易平台提供了完整的技术架构方案，既考虑了当前需求，也为未来扩展留有余地。