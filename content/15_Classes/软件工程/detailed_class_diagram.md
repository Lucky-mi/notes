@startuml 校园二手交易平台详细类图

!theme aws-orange
skinparam backgroundColor #FAFAFA
skinparam classAttributeIconSize 0
skinparam linetype ortho

package "Shared Kernel" {
    abstract class BaseEntity {
        + id: UUID
        + createdAt: DateTime
        + updatedAt: DateTime
    }
    
    class Page<T> {
        + content: List<T>
        + total: long
        + page: int
        + size: int
    }

    class UserDTO {
        + userId: UUID
        + username: String
        + role: UserRole
    }
}

package "Product Management Module" {
    
    class ProductController {
        - productService: ProductService
        + createProduct(req: ProductCreateRequest, currentUser: UserDTO): ProductResponse
        + updateProduct(id: UUID, req: ProductUpdateRequest, currentUser: UserDTO): ProductResponse
        + deleteProduct(id: UUID, currentUser: UserDTO): void
        + getProduct(id: UUID): ProductResponse
        + searchProducts(query: ProductSearchQuery): Page<ProductResponse>
        + uploadImages(files: List<File>): List<String>
    }

    class ProductService {
        - productRepository: ProductRepository
        - fileService: FileService
        - searchService: SearchService
        - eventBus: EventBus
        + create(userId: UUID, req: ProductCreateRequest): Product
        + update(userId: UUID, productId: UUID, req: ProductUpdateRequest): Product
        + delete(userId: UUID, productId: UUID): void
        + getById(id: UUID): Product
        + search(query: ProductSearchQuery): Page<Product>
        + lockProduct(id: UUID): void
        + unlockProduct(id: UUID): void
        + markAsSold(id: UUID): void
    }

    interface ProductRepository {
        + save(product: Product): Product
        + findById(id: UUID): Optional<Product>
        + findBySellerId(sellerId: UUID, pageable: Pageable): Page<Product>
        + findAll(spec: Specification): Page<Product>
        + deleteById(id: UUID): void
    }

    class Product extends BaseEntity {
        - sellerId: UUID
        - title: String
        - description: String
        - price: Decimal
        - categoryId: UUID
        - condition: ProductCondition
        - status: ProductStatus
        - location: String
        - images: List<String>
        - viewCount: int
        + publish(): void
        + updateInfo(info: ProductUpdateRequest): void
        + lock(): void
        + unlock(): void
        + sold(): void
    }

    enum ProductStatus {
        DRAFT
        PUBLISHED
        LOCKED
        SOLD
        REMOVED
    }

    class ProductCreateRequest {
        + title: String
        + description: String
        + price: Decimal
        + categoryId: UUID
        + images: List<String>
        + location: String
    }
}

package "Order Transaction Module" {

    class TransactionController {
        - transactionService: TransactionService
        + createOrder(req: OrderCreateRequest, currentUser: UserDTO): TransactionResponse
        + confirmOrder(id: UUID, currentUser: UserDTO): void
        + payOrder(id: UUID, currentUser: UserDTO): void
        + completeOrder(id: UUID, currentUser: UserDTO): void
        + cancelOrder(id: UUID, req: CancelRequest, currentUser: UserDTO): void
        + getTransaction(id: UUID): TransactionResponse
        + getMyOrders(currentUser: UserDTO): Page<TransactionResponse>
    }

    class TransactionService {
        - transactionRepository: TransactionRepository
        - productService: ProductService
        - userService: UserService
        - notificationService: NotificationService
        + createTransaction(buyerId: UUID, req: OrderCreateRequest): Transaction
        + confirmTransaction(sellerId: UUID, transactionId: UUID): void
        + processPayment(userId: UUID, transactionId: UUID): void
        + completeTransaction(userId: UUID, transactionId: UUID): void
        + cancelTransaction(userId: UUID, transactionId: UUID, reason: String): void
        - validateTransactionState(transaction: Transaction, action: TransactionAction): void
    }

    interface TransactionRepository {
        + save(transaction: Transaction): Transaction
        + findById(id: UUID): Optional<Transaction>
        + findByBuyerId(buyerId: UUID, pageable: Pageable): Page<Transaction>
        + findBySellerId(sellerId: UUID, pageable: Pageable): Page<Transaction>
    }

    class Transaction extends BaseEntity {
        - productId: UUID
        - buyerId: UUID
        - sellerId: UUID
        - amount: Decimal
        - status: TransactionStatus
        - meetingLocation: String
        - meetingTime: DateTime
        - cancellationReason: String
        + confirm(): void
        + pay(): void
        + complete(): void
        + cancel(reason: String): void
    }

    enum TransactionStatus {
        PENDING
        CONFIRMED
        PAID
        COMPLETED
        CANCELLED
        DISPUTED
    }
    
    class OrderCreateRequest {
        + productId: UUID
        + meetingLocation: String
        + meetingTime: DateTime
        + note: String
    }
}

' Relationships within Product Module
ProductController --> ProductService
ProductService --> ProductRepository
ProductService --> Product
ProductRepository ..> Product
ProductService ..> ProductCreateRequest

' Relationships within Transaction Module
TransactionController --> TransactionService
TransactionService --> TransactionRepository
TransactionService --> Transaction
TransactionRepository ..> Transaction
TransactionService ..> OrderCreateRequest

' Cross-module dependencies
TransactionService --> ProductService : 1. check availability\n2. lock product\n3. mark sold
Transaction --> Product : references (via ID)

@enduml