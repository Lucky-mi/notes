@startuml 校园二手交易平台核心流程时序图

!theme aws-orange

title 商品发布到交易完成的完整流程

actor "卖家" as Seller
actor "买家" as Buyer
participant "Web前端" as Frontend
participant "API网关" as Gateway
participant "认证服务" as AuthService
participant "商品服务" as ProductService
participant "文件服务" as FileService
participant "搜索服务" as SearchService
participant "消息服务" as MessageService
participant "交易服务" as TransactionService
participant "通知服务" as NotificationService
participant "数据库" as Database
participant "缓存" as Cache

== 商品发布流程 ==

Seller -> Frontend: 登录并进入发布页面
Frontend -> Gateway: POST /auth/login
Gateway -> AuthService: 验证用户身份
AuthService -> Database: 查询用户信息
note right
    Input: {
        "student_id": "string",
        "password": "string"
    }
end note
Database --> AuthService: 返回用户数据
AuthService --> Gateway: 返回JWT Token
note right
    Output: {
        "token": "string",
        "user_info": {
            "user_id": "uuid",
            "username": "string",
            "role": "string"
        }
    }
end note
Gateway --> Frontend: 登录成功

Seller -> Frontend: 填写商品信息并上传图片
Frontend -> Gateway: POST /products/create
Gateway -> ProductService: 创建商品
ProductService -> FileService: 上传商品图片
note right
    Input: {
        "images": ["file1", "file2"],
        "product_info": {
            "title": "string",
            "description": "string",
            "price": "decimal",
            "category_id": "uuid"
        }
    }
end note
FileService -> Database: 保存图片信息
FileService --> ProductService: 返回图片URL列表
ProductService -> Database: 保存商品信息
Database --> ProductService: 返回商品ID
ProductService -> SearchService: 更新搜索索引
ProductService -> Cache: 缓存商品信息
ProductService --> Gateway: 商品发布成功
note right
    Output: {
        "product_id": "uuid",
        "status": "published",
        "created_at": "datetime"
    }
end note
Gateway --> Frontend: 返回发布结果
Frontend --> Seller: 显示发布成功

== 商品搜索和浏览流程 ==

Buyer -> Frontend: 搜索商品
Frontend -> Gateway: GET /products/search?keyword=xxx
Gateway -> SearchService: 执行搜索
SearchService -> Cache: 检查缓存
Cache --> SearchService: 返回缓存结果（如有）
alt 缓存未命中
    SearchService -> Database: 查询商品数据
    Database --> SearchService: 返回搜索结果
    SearchService -> Cache: 更新缓存
end
SearchService --> Gateway: 返回商品列表
note right
    Output: {
        "products": [{
            "product_id": "uuid",
            "title": "string",
            "price": "decimal",
            "images": ["url1", "url2"],
            "seller_info": {
                "username": "string",
                "credit_score": "float"
            }
        }],
        "total": "int",
        "page": "int"
    }
end note
Gateway --> Frontend: 商品搜索结果
Frontend --> Buyer: 显示商品列表

== 沟通议价流程 ==

Buyer -> Frontend: 点击联系卖家
Frontend -> Gateway: POST /messages/start-conversation
Gateway -> MessageService: 创建对话
MessageService -> Database: 保存对话信息
MessageService -> NotificationService: 发送通知给卖家
NotificationService -> Seller: 推送新消息通知
MessageService --> Gateway: 对话创建成功
Gateway --> Frontend: 返回对话ID

Buyer -> Frontend: 发送议价消息
Frontend -> Gateway: POST /messages/send
Gateway -> MessageService: 发送消息
note right
    Input: {
        "conversation_id": "uuid",
        "content": "string",
        "message_type": "text"
    }
end note
MessageService -> Database: 保存消息
MessageService -> NotificationService: 通知接收方
NotificationService -> Seller: 实时推送消息
MessageService --> Gateway: 消息发送成功
Gateway --> Frontend: 确认发送

== 交易确认流程 ==

Seller -> Frontend: 同意买家出价
Frontend -> Gateway: POST /transactions/create
Gateway -> TransactionService: 创建交易订单
note right
    Input: {
        "product_id": "uuid",
        "buyer_id": "uuid",
        "agreed_price": "decimal",
        "meeting_location": "string",
        "meeting_time": "datetime"
    }
end note
TransactionService -> Database: 保存交易信息
TransactionService -> ProductService: 更新商品状态为"已预订"
ProductService -> Database: 更新商品状态
TransactionService -> NotificationService: 通知双方
NotificationService -> Buyer: 发送交易确认通知
NotificationService -> Seller: 发送交易确认通知
TransactionService --> Gateway: 交易创建成功
note right
    Output: {
        "transaction_id": "uuid",
        "status": "confirmed",
        "meeting_info": {
            "location": "string",
            "time": "datetime"
        }
    }
end note
Gateway --> Frontend: 返回交易信息

== 交易完成流程 ==

Buyer -> Frontend: 确认收货并完成交易
Frontend -> Gateway: POST /transactions/complete
Gateway -> TransactionService: 完成交易
TransactionService -> Database: 更新交易状态
TransactionService -> ProductService: 更新商品状态为"已售出"
ProductService -> Database: 更新商品状态
TransactionService -> NotificationService: 通知交易完成
NotificationService -> Seller: 发送交易完成通知
NotificationService -> Buyer: 发送交易完成通知
TransactionService --> Gateway: 交易完成
Gateway --> Frontend: 确认完成

Frontend --> Buyer: 跳转到评价页面
Frontend --> Seller: 显示交易完成

@enduml