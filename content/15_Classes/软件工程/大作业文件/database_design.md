# 校园二手交易平台 - 数据库设计文档

## 1. 数据库设计概述

### 1.1 设计原则

1. **数据完整性**：通过主键、外键、约束确保数据一致性
2. **性能优化**：合理设计索引，支持高并发查询
3. **扩展性**：支持水平和垂直扩展
4. **安全性**：敏感数据加密存储，访问控制
5. **可维护性**：清晰的命名规范和文档

### 1.2 技术选型

- **主数据库**：PostgreSQL 14+
  - 支持JSON数据类型，灵活存储配置信息
  - 强大的全文搜索功能
  - 优秀的事务支持和并发控制
  - 丰富的数据类型和扩展功能

- **缓存数据库**：Redis 6+
  - 用户会话缓存
  - 热点商品数据缓存
  - 搜索结果缓存
  - 消息队列

- **搜索引擎**：Elasticsearch 8+
  - 商品全文搜索
  - 实时搜索建议
  - 复杂筛选和聚合

## 2. 核心实体设计

### 2.1 用户模块 (User Module)

#### 2.1.1 users 表
```sql
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id VARCHAR(20) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    avatar_url VARCHAR(500),
    real_name VARCHAR(50) NOT NULL,
    school VARCHAR(100) NOT NULL,
    college VARCHAR(100) NOT NULL,
    grade INTEGER NOT NULL,
    dormitory VARCHAR(100),
    status user_status DEFAULT 'active',
    credit_score DECIMAL(5,2) DEFAULT 100.00,
    verification_status BOOLEAN DEFAULT FALSE,
    graduation_date DATE,
    last_login_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended', 'graduated');

-- 索引设计
CREATE INDEX idx_users_student_id ON users(student_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_school_college ON users(school, college);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_credit_score ON users(credit_score);
CREATE INDEX idx_users_created_at ON users(created_at);
```

**字段说明：**
- `user_id`：主键，使用UUID确保全局唯一
- `student_id`：学号，校园身份认证的关键字段
- `credit_score`：信誉分数，影响交易权限和推荐排序
- `verification_status`：身份验证状态，确保平台封闭性
- `graduation_date`：毕业日期，用于毕业生特殊处理

#### 2.1.2 user_profiles 表
```sql
CREATE TABLE user_profiles (
    profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    id_card VARCHAR(18),
    student_card_url VARCHAR(500),
    bio TEXT,
    preferences JSONB,
    privacy_settings JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_user_profiles_user_id ON user_profiles(user_id);
```

### 2.2 商品模块 (Product Module)

#### 2.2.1 categories 表
```sql
CREATE TABLE categories (
    category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID REFERENCES categories(category_id),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon_url VARCHAR(500),
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_categories_parent_id ON categories(parent_id);
CREATE INDEX idx_categories_name ON categories(name);
CREATE INDEX idx_categories_sort_order ON categories(sort_order);
```

#### 2.2.2 products 表
```sql
CREATE TABLE products (
    product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES users(user_id),
    category_id UUID NOT NULL REFERENCES categories(category_id),
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    original_price DECIMAL(10,2),
    condition product_condition NOT NULL,
    status product_status DEFAULT 'draft',
    location VARCHAR(200) NOT NULL,
    tags JSONB,
    view_count INTEGER DEFAULT 0,
    favorite_count INTEGER DEFAULT 0,
    is_urgent BOOLEAN DEFAULT FALSE,
    is_negotiable BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    published_at TIMESTAMP,
    sold_at TIMESTAMP
);

CREATE TYPE product_condition AS ENUM ('new', 'like_new', 'good', 'fair', 'poor');
CREATE TYPE product_status AS ENUM ('draft', 'published', 'sold', 'removed');

-- 索引设计
CREATE INDEX idx_products_seller_id ON products(seller_id);
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_status ON products(status);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_products_created_at ON products(created_at DESC);
CREATE INDEX idx_products_published_at ON products(published_at DESC);
CREATE INDEX idx_products_location ON products(location);
CREATE INDEX idx_products_is_urgent ON products(is_urgent);
CREATE INDEX idx_products_view_count ON products(view_count DESC);
CREATE INDEX idx_products_favorite_count ON products(favorite_count DESC);

-- 全文搜索索引
CREATE INDEX idx_products_search ON products USING gin(to_tsvector('chinese', title || ' ' || description));
```

#### 2.2.3 product_images 表
```sql
CREATE TABLE product_images (
    image_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    image_url VARCHAR(500) NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    order_index INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_product_images_product_id ON product_images(product_id);
CREATE INDEX idx_product_images_is_primary ON product_images(is_primary);
CREATE INDEX idx_product_images_order_index ON product_images(order_index);
```

### 2.3 交易模块 (Transaction Module)

#### 2.3.1 transactions 表
```sql
CREATE TABLE transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(product_id),
    buyer_id UUID NOT NULL REFERENCES users(user_id),
    seller_id UUID NOT NULL REFERENCES users(user_id),
    agreed_price DECIMAL(10,2) NOT NULL,
    payment_method payment_method_type,
    status transaction_status DEFAULT 'pending',
    meeting_location VARCHAR(200),
    meeting_time TIMESTAMP,
    notes TEXT,
    cancellation_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

CREATE TYPE payment_method_type AS ENUM ('cash', 'alipay', 'wechat_pay', 'bank_transfer');
CREATE TYPE transaction_status AS ENUM ('pending', 'confirmed', 'paid', 'completed', 'cancelled', 'disputed');

-- 索引设计
CREATE INDEX idx_transactions_product_id ON transactions(product_id);
CREATE INDEX idx_transactions_buyer_id ON transactions(buyer_id);
CREATE INDEX idx_transactions_seller_id ON transactions(seller_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_created_at ON transactions(created_at DESC);
CREATE INDEX idx_transactions_meeting_time ON transactions(meeting_time);
```

#### 2.3.2 conversations 表
```sql
CREATE TABLE conversations (
    conversation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(product_id),
    buyer_id UUID NOT NULL REFERENCES users(user_id),
    seller_id UUID NOT NULL REFERENCES users(user_id),
    last_message_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_conversations_product_buyer ON conversations(product_id, buyer_id);
CREATE INDEX idx_conversations_buyer_id ON conversations(buyer_id);
CREATE INDEX idx_conversations_seller_id ON conversations(seller_id);
CREATE INDEX idx_conversations_last_message_at ON conversations(last_message_at DESC);
```

#### 2.3.3 messages 表
```sql
CREATE TABLE messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(user_id),
    receiver_id UUID NOT NULL REFERENCES users(user_id),
    content TEXT NOT NULL,
    message_type message_type_enum DEFAULT 'text',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TYPE message_type_enum AS ENUM ('text', 'image', 'location', 'system');

CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_messages_sender_id ON messages(sender_id);
CREATE INDEX idx_messages_receiver_id ON messages(receiver_id);
CREATE INDEX idx_messages_is_read ON messages(is_read);
CREATE INDEX idx_messages_created_at ON messages(created_at DESC);
```

### 2.4 评价模块 (Review Module)

#### 2.4.1 reviews 表
```sql
CREATE TABLE reviews (
    review_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES transactions(transaction_id),
    reviewer_id UUID NOT NULL REFERENCES users(user_id),
    reviewee_id UUID NOT NULL REFERENCES users(user_id),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    review_type review_type_enum NOT NULL,
    is_anonymous BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TYPE review_type_enum AS ENUM ('buyer_to_seller', 'seller_to_buyer');

CREATE INDEX idx_reviews_transaction_id ON reviews(transaction_id);
CREATE INDEX idx_reviews_reviewer_id ON reviews(reviewer_id);
CREATE INDEX idx_reviews_reviewee_id ON reviews(reviewee_id);
CREATE INDEX idx_reviews_rating ON reviews(rating);
CREATE INDEX idx_reviews_created_at ON reviews(created_at DESC);
```

#### 2.4.2 credit_records 表
```sql
CREATE TABLE credit_records (
    record_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(user_id),
    transaction_id UUID REFERENCES transactions(transaction_id),
    score_change DECIMAL(5,2) NOT NULL,
    reason VARCHAR(200) NOT NULL,
    operation_type operation_type_enum NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TYPE operation_type_enum AS ENUM ('increase', 'decrease');

CREATE INDEX idx_credit_records_user_id ON credit_records(user_id);
CREATE INDEX idx_credit_records_transaction_id ON credit_records(transaction_id);
CREATE INDEX idx_credit_records_created_at ON credit_records(created_at DESC);
```

### 2.5 安全模块 (Security Module)

#### 2.5.1 reports 表
```sql
CREATE TABLE reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(user_id),
    reported_user_id UUID REFERENCES users(user_id),
    reported_product_id UUID REFERENCES products(product_id),
    report_type report_type_enum NOT NULL,
    reason TEXT NOT NULL,
    evidence JSONB,
    status report_status_enum DEFAULT 'pending',
    handler_id UUID REFERENCES admin_users(admin_id),
    handled_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TYPE report_type_enum AS ENUM ('fraud', 'fake_product', 'inappropriate_content', 'harassment', 'other');
CREATE TYPE report_status_enum AS ENUM ('pending', 'investigating', 'resolved', 'rejected');

CREATE INDEX idx_reports_reporter_id ON reports(reporter_id);
CREATE INDEX idx_reports_reported_user_id ON reports(reported_user_id);
CREATE INDEX idx_reports_reported_product_id ON reports(reported_product_id);
CREATE INDEX idx_reports_status ON reports(status);
CREATE INDEX idx_reports_created_at ON reports(created_at DESC);
```

## 3. 关系设计说明

### 3.1 一对一关系 (1:1)
- `users` ↔ `user_profiles`：每个用户有一个详细档案

### 3.2 一对多关系 (1:N)
- `users` → `products`：一个用户可以发布多个商品
- `users` → `transactions`：一个用户可以参与多个交易（买家或卖家）
- `products` → `product_images`：一个商品可以有多张图片
- `products` → `transactions`：一个商品可以有多次交易记录
- `categories` → `categories`：分类的层级关系
- `conversations` → `messages`：一个对话包含多条消息

### 3.3 多对多关系 (M:N)
- `users` ↔ `products`：通过 `product_favorites` 表实现收藏关系
- `users` ↔ `users`：通过 `blacklist` 表实现拉黑关系

## 4. 索引策略

### 4.1 主键索引
所有表都使用UUID作为主键，自动创建唯一索引。

### 4.2 外键索引
为所有外键字段创建索引，提高关联查询性能。

### 4.3 业务索引
- **搜索相关**：商品标题、描述的全文搜索索引
- **排序相关**：创建时间、价格、浏览量、收藏量
- **筛选相关**：商品状态、分类、地区、价格区间
- **用户相关**：学号、邮箱、手机号的唯一索引

### 4.4 复合索引
```sql
-- 商品搜索复合索引
CREATE INDEX idx_products_search_filter ON products(status, category_id, price, created_at DESC);

-- 用户交易历史复合索引
CREATE INDEX idx_transactions_user_status ON transactions(buyer_id, seller_id, status, created_at DESC);

-- 消息查询复合索引
CREATE INDEX idx_messages_conversation_time ON messages(conversation_id, created_at DESC);
```

## 5. 数据安全设计

### 5.1 敏感数据加密
- 用户密码使用bcrypt加密存储
- 身份证号码使用AES-256加密
- 手机号码部分脱敏显示

### 5.2 数据访问控制
- 行级安全策略（Row Level Security）
- 用户只能访问自己的私人数据
- 管理员权限分级控制

### 5.3 审计日志
```sql
CREATE TABLE audit_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(user_id),
    admin_id UUID REFERENCES admin_users(admin_id),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    resource_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);
```

## 6. 性能优化策略

### 6.1 分区表设计
```sql
-- 按时间分区的消息表
CREATE TABLE messages (
    message_id UUID,
    conversation_id UUID,
    sender_id UUID,
    receiver_id UUID,
    content TEXT,
    message_type message_type_enum,
    is_read BOOLEAN,
    created_at TIMESTAMP
) PARTITION BY RANGE (created_at);

-- 创建月度分区
CREATE TABLE messages_2024_01 PARTITION OF messages
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

### 6.2 读写分离
- 主库处理写操作和实时性要求高的读操作
- 从库处理统计查询和报表生成
- 使用连接池管理数据库连接

### 6.3 缓存策略
- Redis缓存热点商品数据
- 用户会话信息缓存
- 搜索结果缓存（TTL: 5分钟）
- 用户信誉分数缓存

## 7. 数据备份和恢复

### 7.1 备份策略
- 全量备份：每日凌晨3点
- 增量备份：每4小时一次
- 事务日志备份：每15分钟一次

### 7.2 恢复策略
- 支持点时间恢复（Point-in-Time Recovery）
- 异地备份存储
- 定期恢复测试

## 8. 监控和维护

### 8.1 性能监控
- 慢查询日志监控
- 连接数监控
- 缓存命中率监控
- 磁盘空间监控

### 8.2 数据维护
- 定期清理过期数据
- 重建索引和更新统计信息
- 数据归档策略

这个数据库设计为校园二手交易平台提供了完整的数据存储方案，既保证了数据的完整性和一致性，又考虑了性能和扩展性需求。