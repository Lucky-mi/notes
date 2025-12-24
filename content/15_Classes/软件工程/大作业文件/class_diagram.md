@startuml 校园二手交易平台类图

!theme aws-orange

package "用户模块 (User Module)" {
    class User {
        +user_id: UUID
        +student_id: str
        +username: str
        +email: str
        +phone: str
        +avatar_url: str
        +school: str
        +college: str
        +grade: int
        +status: UserStatus
        +credit_score: float
        +created_at: datetime
        +updated_at: datetime
        --
        +register(user_data: dict): bool
        +authenticate(credentials: dict): bool
        +update_profile(profile_data: dict): bool
        +get_credit_score(): float
    }
    
    enum UserStatus {
        ACTIVE
        INACTIVE
        SUSPENDED
        GRADUATED
    }
    
    class UserProfile {
        +profile_id: UUID
        +user_id: UUID
        +real_name: str
        +id_card: str
        +dormitory: str
        +verification_status: bool
        +graduation_date: datetime
        --
        +verify_identity(documents: list): bool
        +update_info(info: dict): bool
    }
}

package "商品模块 (Product Module)" {
    class Product {
        +product_id: UUID
        +seller_id: UUID
        +title: str
        +description: str
        +price: decimal
        +original_price: decimal
        +category_id: UUID
        +condition: ProductCondition
        +status: ProductStatus
        +location: str
        +images: list[str]
        +tags: list[str]
        +view_count: int
        +favorite_count: int
        +created_at: datetime
        +updated_at: datetime
        --
        +publish(): bool
        +update_info(product_data: dict): bool
        +change_status(status: ProductStatus): bool
        +add_images(images: list): bool
        +get_recommendations(): list[Product]
    }
    
    enum ProductCondition {
        NEW
        LIKE_NEW
        GOOD
        FAIR
        POOR
    }
    
    enum ProductStatus {
        DRAFT
        PUBLISHED
        SOLD
        REMOVED
    }
    
    class Category {
        +category_id: UUID
        +name: str
        +parent_id: UUID
        +description: str
        +icon_url: str
        --
        +get_subcategories(): list[Category]
        +get_products(): list[Product]
    }
    
    class ProductImage {
        +image_id: UUID
        +product_id: UUID
        +image_url: str
        +is_primary: bool
        +order_index: int
        --
        +upload_image(file: bytes): str
        +delete_image(): bool
    }
}

package "交易模块 (Transaction Module)" {
    class Transaction {
        +transaction_id: UUID
        +product_id: UUID
        +buyer_id: UUID
        +seller_id: UUID
        +price: decimal
        +status: TransactionStatus
        +payment_method: PaymentMethod
        +meeting_location: str
        +meeting_time: datetime
        +notes: str
        +created_at: datetime
        +completed_at: datetime
        --
        +create_order(): bool
        +confirm_payment(): bool
        +complete_transaction(): bool
        +cancel_transaction(reason: str): bool
    }
    
    enum TransactionStatus {
        PENDING
        CONFIRMED
        PAID
        COMPLETED
        CANCELLED
        DISPUTED
    }
    
    enum PaymentMethod {
        CASH
        ALIPAY
        WECHAT_PAY
        BANK_TRANSFER
    }
    
    class Message {
        +message_id: UUID
        +transaction_id: UUID
        +sender_id: UUID
        +receiver_id: UUID
        +content: str
        +message_type: MessageType
        +is_read: bool
        +created_at: datetime
        --
        +send_message(): bool
        +mark_as_read(): bool
        +get_conversation(): list[Message]
    }
    
    enum MessageType {
        TEXT
        IMAGE
        LOCATION
        SYSTEM
    }
}

package "评价模块 (Review Module)" {
    class Review {
        +review_id: UUID
        +transaction_id: UUID
        +reviewer_id: UUID
        +reviewee_id: UUID
        +rating: int
        +comment: str
        +review_type: ReviewType
        +created_at: datetime
        --
        +submit_review(): bool
        +calculate_average_rating(): float
    }
    
    enum ReviewType {
        BUYER_TO_SELLER
        SELLER_TO_BUYER
    }
    
    class CreditRecord {
        +record_id: UUID
        +user_id: UUID
        +transaction_id: UUID
        +score_change: float
        +reason: str
        +created_at: datetime
        --
        +update_credit_score(): bool
        +get_credit_history(): list[CreditRecord]
    }
}

package "安全模块 (Security Module)" {
    class Report {
        +report_id: UUID
        +reporter_id: UUID
        +reported_user_id: UUID
        +reported_product_id: UUID
        +report_type: ReportType
        +reason: str
        +evidence: list[str]
        +status: ReportStatus
        +created_at: datetime
        +handled_at: datetime
        --
        +submit_report(): bool
        +handle_report(action: str): bool
    }
    
    enum ReportType {
        FRAUD
        FAKE_PRODUCT
        INAPPROPRIATE_CONTENT
        HARASSMENT
        OTHER
    }
    
    enum ReportStatus {
        PENDING
        INVESTIGATING
        RESOLVED
        REJECTED
    }
}

' 关系定义
User ||--o{ Product : "sells"
User ||--o{ Transaction : "buys/sells"
User ||--|| UserProfile : "has"
User ||--o{ Review : "gives/receives"
User ||--o{ CreditRecord : "has"
User ||--o{ Report : "reports/reported"

Product }o--|| Category : "belongs to"
Product ||--o{ ProductImage : "has"
Product ||--o{ Transaction : "involved in"

Transaction ||--o{ Message : "contains"
Transaction ||--|| Review : "results in"

UserStatus ||--o{ User
ProductCondition ||--o{ Product
ProductStatus ||--o{ Product
TransactionStatus ||--o{ Transaction
PaymentMethod ||--o{ Transaction
MessageType ||--o{ Message
ReviewType ||--o{ Review
ReportType ||--o{ Report
ReportStatus ||--o{ Report

@enduml