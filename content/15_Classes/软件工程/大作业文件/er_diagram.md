@startuml 校园二手交易平台ER图

!theme aws-orange
skinparam backgroundColor #FAFAFA

' 用户相关实体
entity "users" as users {
  * user_id : UUID <<PK>>
  --
  * student_id : VARCHAR(20) <<UK>>
  * username : VARCHAR(50) <<UK>>
  * email : VARCHAR(100) <<UK>>
  * phone : VARCHAR(20) <<UK>>
  * password_hash : VARCHAR(255)
  * avatar_url : VARCHAR(500)
  * real_name : VARCHAR(50)
  * school : VARCHAR(100)
  * college : VARCHAR(100)
  * grade : INTEGER
  * dormitory : VARCHAR(100)
  * status : ENUM('active', 'inactive', 'suspended', 'graduated')
  * credit_score : DECIMAL(5,2) DEFAULT 100.00
  * verification_status : BOOLEAN DEFAULT FALSE
  * graduation_date : DATE
  * last_login_at : TIMESTAMP
  * created_at : TIMESTAMP
  * updated_at : TIMESTAMP
}

entity "user_profiles" as profiles {
  * profile_id : UUID <<PK>>
  --
  * user_id : UUID <<FK>>
  * id_card : VARCHAR(18)
  * student_card_url : VARCHAR(500)
  * bio : TEXT
  * preferences : JSON
  * privacy_settings : JSON
  * created_at : TIMESTAMP
  * updated_at : TIMESTAMP
}

' 商品相关实体
entity "categories" as categories {
  * category_id : UUID <<PK>>
  --
  * parent_id : UUID <<FK>>
  * name : VARCHAR(100)
  * description : TEXT
  * icon_url : VARCHAR(500)
  * sort_order : INTEGER
  * is_active : BOOLEAN DEFAULT TRUE
  * created_at : TIMESTAMP
  * updated_at : TIMESTAMP
}

entity "products" as products {
  * product_id : UUID <<PK>>
  --
  * seller_id : UUID <<FK>>
  * category_id : UUID <<FK>>
  * title : VARCHAR(200)
  * description : TEXT
  * price : DECIMAL(10,2)
  * original_price : DECIMAL(10,2)
  * condition : ENUM('new', 'like_new', 'good', 'fair', 'poor')
  * status : ENUM('draft', 'published', 'sold', 'removed')
  * location : VARCHAR(200)
  * tags : JSON
  * view_count : INTEGER DEFAULT 0
  * favorite_count : INTEGER DEFAULT 0
  * is_urgent : BOOLEAN DEFAULT FALSE
  * is_negotiable : BOOLEAN DEFAULT TRUE
  * created_at : TIMESTAMP
  * updated_at : TIMESTAMP
  * published_at : TIMESTAMP
  * sold_at : TIMESTAMP
}

entity "product_images" as product_images {
  * image_id : UUID <<PK>>
  --
  * product_id : UUID <<FK>>
  * image_url : VARCHAR(500)
  * is_primary : BOOLEAN DEFAULT FALSE
  * order_index : INTEGER
  * created_at : TIMESTAMP
}

entity "product_favorites" as favorites {
  * favorite_id : UUID <<PK>>
  --
  * user_id : UUID <<FK>>
  * product_id : UUID <<FK>>
  * created_at : TIMESTAMP
}

' 交易相关实体
entity "transactions" as transactions {
  * transaction_id : UUID <<PK>>
  --
  * product_id : UUID <<FK>>
  * buyer_id : UUID <<FK>>
  * seller_id : UUID <<FK>>
  * agreed_price : DECIMAL(10,2)
  * payment_method : ENUM('cash', 'alipay', 'wechat_pay', 'bank_transfer')
  * status : ENUM('pending', 'confirmed', 'paid', 'completed', 'cancelled', 'disputed')
  * meeting_location : VARCHAR(200)
  * meeting_time : TIMESTAMP
  * notes : TEXT
  * cancellation_reason : TEXT
  * created_at : TIMESTAMP
  * updated_at : TIMESTAMP
  * completed_at : TIMESTAMP
}

entity "messages" as messages {
  * message_id : UUID <<PK>>
  --
  * conversation_id : UUID <<FK>>
  * sender_id : UUID <<FK>>
  * receiver_id : UUID <<FK>>
  * content : TEXT
  * message_type : ENUM('text', 'image', 'location', 'system')
  * is_read : BOOLEAN DEFAULT FALSE
  * created_at : TIMESTAMP
}

entity "conversations" as conversations {
  * conversation_id : UUID <<PK>>
  --
  * product_id : UUID <<FK>>
  * buyer_id : UUID <<FK>>
  * seller_id : UUID <<FK>>
  * last_message_at : TIMESTAMP
  * created_at : TIMESTAMP
  * updated_at : TIMESTAMP
}

' 评价相关实体
entity "reviews" as reviews {
  * review_id : UUID <<PK>>
  --
  * transaction_id : UUID <<FK>>
  * reviewer_id : UUID <<FK>>
  * reviewee_id : UUID <<FK>>
  * rating : INTEGER CHECK (rating >= 1 AND rating <= 5)
  * comment : TEXT
  * review_type : ENUM('buyer_to_seller', 'seller_to_buyer')
  * is_anonymous : BOOLEAN DEFAULT FALSE
  * created_at : TIMESTAMP
  * updated_at : TIMESTAMP
}

entity "credit_records" as credit_records {
  * record_id : UUID <<PK>>
  --
  * user_id : UUID <<FK>>
  * transaction_id : UUID <<FK>>
  * score_change : DECIMAL(5,2)
  * reason : VARCHAR(200)
  * operation_type : ENUM('increase', 'decrease')
  * created_at : TIMESTAMP
}

' 安全相关实体
entity "reports" as reports {
  * report_id : UUID <<PK>>
  --
  * reporter_id : UUID <<FK>>
  * reported_user_id : UUID <<FK>>
  * reported_product_id : UUID <<FK>>
  * report_type : ENUM('fraud', 'fake_product', 'inappropriate_content', 'harassment', 'other')
  * reason : TEXT
  * evidence : JSON
  * status : ENUM('pending', 'investigating', 'resolved', 'rejected')
  * handler_id : UUID <<FK>>
  * handled_at : TIMESTAMP
  * created_at : TIMESTAMP
  * updated_at : TIMESTAMP
}

entity "blacklist" as blacklist {
  * blacklist_id : UUID <<PK>>
  --
  * user_id : UUID <<FK>>
  * blocked_user_id : UUID <<FK>>
  * reason : TEXT
  * created_at : TIMESTAMP
}

' 通知相关实体
entity "notifications" as notifications {
  * notification_id : UUID <<PK>>
  --
  * user_id : UUID <<FK>>
  * type : ENUM('message', 'transaction', 'system', 'review', 'favorite')
  * title : VARCHAR(200)
  * content : TEXT
  * data : JSON
  * is_read : BOOLEAN DEFAULT FALSE
  * created_at : TIMESTAMP
  * read_at : TIMESTAMP
}

' 系统相关实体
entity "admin_users" as admin_users {
  * admin_id : UUID <<PK>>
  --
  * username : VARCHAR(50) <<UK>>
  * email : VARCHAR(100) <<UK>>
  * password_hash : VARCHAR(255)
  * role : ENUM('super_admin', 'admin', 'moderator')
  * permissions : JSON
  * is_active : BOOLEAN DEFAULT TRUE
  * last_login_at : TIMESTAMP
  * created_at : TIMESTAMP
  * updated_at : TIMESTAMP
}

entity "system_configs" as configs {
  * config_id : UUID <<PK>>
  --
  * key : VARCHAR(100) <<UK>>
  * value : TEXT
  * description : TEXT
  * is_active : BOOLEAN DEFAULT TRUE
  * created_at : TIMESTAMP
  * updated_at : TIMESTAMP
}

entity "audit_logs" as audit_logs {
  * log_id : UUID <<PK>>
  --
  * user_id : UUID <<FK>>
  * admin_id : UUID <<FK>>
  * action : VARCHAR(100)
  * resource_type : VARCHAR(50)
  * resource_id : UUID
  * old_values : JSON
  * new_values : JSON
  * ip_address : VARCHAR(45)
  * user_agent : TEXT
  * created_at : TIMESTAMP
}

' 关系定义
users ||--|| profiles : "has"
users ||--o{ products : "sells"
users ||--o{ transactions : "buys/sells"
users ||--o{ messages : "sends/receives"
users ||--o{ reviews : "gives/receives"
users ||--o{ credit_records : "has"
users ||--o{ reports : "reports/reported"
users ||--o{ favorites : "favorites"
users ||--o{ blacklist : "blocks/blocked"
users ||--o{ notifications : "receives"
users ||--o{ conversations : "participates"
users ||--o{ audit_logs : "performs"

categories ||--o{ categories : "parent/child"
categories ||--o{ products : "contains"

products ||--o{ product_images : "has"
products ||--o{ transactions : "involved_in"
products ||--o{ favorites : "favorited"
products ||--o{ conversations : "discussed"
products ||--o{ reports : "reported"

transactions ||--o{ messages : "related_to"
transactions ||--|| reviews : "results_in"
transactions ||--o{ credit_records : "affects"

conversations ||--o{ messages : "contains"

admin_users ||--o{ reports : "handles"
admin_users ||--o{ audit_logs : "performs"

@enduml