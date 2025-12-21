# 校园二手交易平台 - API 接口设计文档

本文档定义了“商品管理”和“订单交易”核心模块的 RESTful API 接口。

## 1. 商品模块 (Product Module)

| 接口描述 | HTTP 方法 | URL 路径 | 关键请求参数 (Body/Query) | 响应内容示例 |
| :--- | :--- | :--- | :--- | :--- |
| **发布商品** | `POST` | `/api/v1/products` | **Body:**<br>`{ "title": "...", "price": 100.0, "categoryId": "uuid", "images": [...] }` | `{ "productId": "uuid", "status": "PUBLISHED", "createdAt": "..." }` |
| **修改商品** | `PUT` | `/api/v1/products/{id}` | **Body:**<br>`{ "title": "New Title", "price": 90.0, "description": "..." }` | `{ "productId": "uuid", "updatedAt": "..." }` |
| **获取商品详情** | `GET` | `/api/v1/products/{id}` | **Path:** `id` (UUID) | `{ "id": "uuid", "title": "...", "seller": { "id": "...", "name": "..." }, "images": [...] }` |
| **搜索商品** | `GET` | `/api/v1/products` | **Query:**<br>`keyword=自行车`<br>`categoryId=uuid`<br>`minPrice=50`<br>`page=1&size=20` | `{ "total": 100, "page": 1, "items": [{ "id": "...", "title": "..." }] }` |
| **修改商品状态** | `PATCH` | `/api/v1/products/{id}/status` | **Body:**<br>`{ "status": "SOLD" }` <br> *(可选值: SOLD, REMOVED)* | `{ "success": true, "currentStatus": "SOLD" }` |
| **上传商品图片** | `POST` | `/api/v1/products/{id}/images` | **Form-Data:**<br>`files=[binary]` | `{ "urls": ["http://.../1.jpg", "http://.../2.jpg"] }` |

## 2. 订单交易模块 (Order/Transaction Module)

| 接口描述 | HTTP 方法 | URL 路径 | 关键请求参数 (Body/Query) | 响应内容示例 |
| :--- | :--- | :--- | :--- | :--- |
| **创建订单** | `POST` | `/api/v1/transactions` | **Body:**<br>`{ "productId": "uuid", "offerPrice": 99.0, "meetingLocation": "食堂门口" }` | `{ "transactionId": "uuid", "status": "PENDING", "amount": 99.0 }` |
| **获取订单详情** | `GET` | `/api/v1/transactions/{id}` | **Path:** `id` (UUID) | `{ "id": "uuid", "product": {...}, "status": "PENDING", "buyer": {...} }` |
| **获取我的订单** | `GET` | `/api/v1/transactions` | **Query:**<br>`role=buyer/seller`<br>`status=PENDING`<br>`page=1` | `{ "total": 5, "items": [{ "id": "...", "productTitle": "..." }] }` |
| **卖家确认接单** | `PATCH` | `/api/v1/transactions/{id}/confirm` | **Path:** `id` (UUID)<br>*(无需 Body)* | `{ "success": true, "status": "CONFIRMED", "updatedAt": "..." }` |
| **买家完成交易** | `PATCH` | `/api/v1/transactions/{id}/complete` | **Path:** `id` (UUID)<br>*(无需 Body)* | `{ "success": true, "status": "COMPLETED", "message": "交易已完成" }` |
| **取消订单** | `PATCH` | `/api/v1/transactions/{id}/cancel` | **Body:**<br>`{ "reason": "不想买了" }` | `{ "success": true, "status": "CANCELLED" }` |

## 3. 通用响应结构

所有接口返回的 JSON 均遵循以下标准结构：

```json
{
  "code": 200,          // 业务状态码 (200: 成功, 400: 参数错误, 401: 未认证, 500: 系统错误)
  "message": "Success", // 提示信息
  "data": { ... }       // 具体的业务数据
}
```

## 4. 状态码说明

- `200 OK`: 请求成功
- `201 Created`: 资源创建成功
- `400 Bad Request`: 请求参数校验失败
- `401 Unauthorized`: 用户未登录或 Token 过期
- `403 Forbidden`: 无权限执行该操作（如修改他人的商品）
- `404 Not Found`: 资源不存在
- `409 Conflict`: 资源状态冲突（如商品已被抢购）