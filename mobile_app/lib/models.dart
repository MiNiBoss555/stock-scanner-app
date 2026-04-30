class Product {
  Product({
    required this.barcode,
    required this.name,
    required this.unit,
    required this.minimumStock,
    required this.currentStock,
    this.sku,
    this.category,
    this.location,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      barcode: json["barcode"] as String,
      name: json["name"] as String,
      unit: (json["unit"] as String?) ?? "pcs",
      minimumStock: (json["minimum_stock"] as num?)?.toInt() ?? 0,
      currentStock: (json["current_stock"] as num?)?.toInt() ?? 0,
      sku: json["sku"] as String?,
      category: json["category"] as String?,
      location: json["location"] as String?,
    );
  }

  final String barcode;
  final String name;
  final String unit;
  final int minimumStock;
  final int currentStock;
  final String? sku;
  final String? category;
  final String? location;

  bool get isLowStock => currentStock <= minimumStock;
}

class AppUser {
  AppUser({
    required this.userId,
    required this.userName,
    required this.role,
    required this.active,
    this.profileImageUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      userId: json["user_id"] as String,
      userName: json["user_name"] as String,
      role: (json["role"] as String?) ?? "staff",
      active: json["active"] as bool? ?? true,
      profileImageUrl: json["profile_image_url"] as String?,
    );
  }

  final String userId;
  final String userName;
  final String role;
  final bool active;
  final String? profileImageUrl;

  bool get isAdmin => role.trim().toLowerCase() == "admin";
}

class LoginSession {
  LoginSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    required this.user,
  });

  factory LoginSession.fromJson(Map<String, dynamic> json) {
    return LoginSession(
      accessToken: json["access_token"] as String,
      tokenType: (json["token_type"] as String?) ?? "bearer",
      expiresAt: DateTime.parse(json["expires_at"] as String).toLocal(),
      user: AppUser.fromJson(json["user"] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final String tokenType;
  final DateTime expiresAt;
  final AppUser user;
}

class ExportLink {
  ExportLink({
    required this.url,
    required this.expiresAt,
  });

  factory ExportLink.fromJson(Map<String, dynamic> json) {
    return ExportLink(
      url: json["url"] as String,
      expiresAt: DateTime.parse(json["expires_at"] as String).toLocal(),
    );
  }

  final String url;
  final DateTime expiresAt;
}

class MovementRecord {
  MovementRecord({
    required this.id,
    required this.barcode,
    required this.productName,
    required this.action,
    required this.quantity,
    required this.beforeStock,
    required this.afterStock,
    required this.actorId,
    required this.actorName,
    required this.createdAt,
    this.note,
    this.reference,
  });

  factory MovementRecord.fromJson(Map<String, dynamic> json) {
    return MovementRecord(
      id: json["id"] as String,
      barcode: json["barcode"] as String,
      productName: json["product_name"] as String,
      action: json["action"] as String,
      quantity: (json["quantity"] as num).toInt(),
      beforeStock: (json["before_stock"] as num).toInt(),
      afterStock: (json["after_stock"] as num).toInt(),
      actorId: json["actor_id"] as String,
      actorName: json["actor_name"] as String,
      createdAt: DateTime.parse(json["created_at"] as String).toLocal(),
      note: json["note"] as String?,
      reference: json["reference"] as String?,
    );
  }

  final String id;
  final String barcode;
  final String productName;
  final String action;
  final int quantity;
  final int beforeStock;
  final int afterStock;
  final String actorId;
  final String actorName;
  final DateTime createdAt;
  final String? note;
  final String? reference;
}

class AppNotification {
  AppNotification({
    required this.title,
    required this.message,
    required this.movementId,
    required this.barcode,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      title: json["title"] as String,
      message: json["message"] as String,
      movementId: json["movement_id"] as String,
      barcode: json["barcode"] as String,
      createdAt: DateTime.parse(json["created_at"] as String).toLocal(),
    );
  }

  final String title;
  final String message;
  final String movementId;
  final String barcode;
  final DateTime createdAt;
}

class StockSummary {
  StockSummary({
    required this.totalProducts,
    required this.totalUnits,
    required this.lowStockCount,
    required this.lowStockItems,
  });

  factory StockSummary.fromJson(Map<String, dynamic> json) {
    final lowStock = (json["low_stock_items"] as List<dynamic>? ?? [])
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();

    return StockSummary(
      totalProducts: (json["total_products"] as num?)?.toInt() ?? 0,
      totalUnits: (json["total_units"] as num?)?.toInt() ?? 0,
      lowStockCount: (json["low_stock_count"] as num?)?.toInt() ?? 0,
      lowStockItems: lowStock,
    );
  }

  final int totalProducts;
  final int totalUnits;
  final int lowStockCount;
  final List<Product> lowStockItems;
}

class ScanResult {
  ScanResult({
    required this.lowStock,
    required this.product,
    required this.movement,
    required this.notification,
    required this.productCreated,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      lowStock: json["low_stock"] as bool? ?? false,
      product: Product.fromJson(json["product"] as Map<String, dynamic>),
      movement: MovementRecord.fromJson(json["movement"] as Map<String, dynamic>),
      notification: AppNotification.fromJson(
        json["notification"] as Map<String, dynamic>,
      ),
      productCreated: json["product_created"] as bool? ?? false,
    );
  }

  final bool lowStock;
  final Product product;
  final MovementRecord movement;
  final AppNotification notification;
  final bool productCreated;
}

class ChatAssistantAction {
  ChatAssistantAction({
    required this.type,
    required this.barcode,
    required this.productName,
    required this.quantity,
    required this.previousStock,
    required this.currentStock,
    required this.lowStock,
    required this.movementId,
  });

  factory ChatAssistantAction.fromJson(Map<String, dynamic> json) {
    return ChatAssistantAction(
      type: json["type"] as String,
      barcode: json["barcode"] as String,
      productName: json["product_name"] as String,
      quantity: (json["quantity"] as num).toInt(),
      previousStock: (json["previous_stock"] as num).toInt(),
      currentStock: (json["current_stock"] as num).toInt(),
      lowStock: json["low_stock"] as bool? ?? false,
      movementId: json["movement_id"] as String,
    );
  }

  final String type;
  final String barcode;
  final String productName;
  final int quantity;
  final int previousStock;
  final int currentStock;
  final bool lowStock;
  final String movementId;
}

class ChatAssistantResult {
  ChatAssistantResult({
    required this.message,
    required this.matchedProducts,
    required this.aiEnabled,
    required this.usedAi,
    this.action,
    this.downloadLink,
  });

  factory ChatAssistantResult.fromJson(Map<String, dynamic> json) {
    final matchedProducts = (json["matched_products"] as List<dynamic>? ?? [])
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();

    return ChatAssistantResult(
      message: json["message"] as String? ?? "",
      matchedProducts: matchedProducts,
      aiEnabled: json["ai_enabled"] as bool? ?? false,
      usedAi: json["used_ai"] as bool? ?? false,
      action: json["action"] == null
          ? null
          : ChatAssistantAction.fromJson(json["action"] as Map<String, dynamic>),
      downloadLink: json["download_link"] == null
          ? null
          : ExportLink.fromJson(json["download_link"] as Map<String, dynamic>),
    );
  }

  final String message;
  final List<Product> matchedProducts;
  final ChatAssistantAction? action;
  final ExportLink? downloadLink;
  final bool aiEnabled;
  final bool usedAi;
}

class OrderItemModel {
  OrderItemModel({
    required this.barcode,
    required this.productName,
    required this.quantity,
    required this.unit,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      barcode: json["barcode"] as String,
      productName: json["product_name"] as String,
      quantity: (json["quantity"] as num).toInt(),
      unit: (json["unit"] as String?) ?? "pcs",
    );
  }

  final String barcode;
  final String productName;
  final int quantity;
  final String unit;
}

class DeliveryOrder {
  DeliveryOrder({
    required this.id,
    required this.customerName,
    required this.createdById,
    required this.createdByName,
    required this.status,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.customerPhone,
    this.customerAddress,
    this.note,
    this.assignedToId,
    this.assignedToName,
  });

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    final items = (json["items"] as List<dynamic>? ?? [])
        .map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
    return DeliveryOrder(
      id: json["id"] as String,
      customerName: json["customer_name"] as String,
      customerPhone: json["customer_phone"] as String?,
      customerAddress: json["customer_address"] as String?,
      note: json["note"] as String?,
      status: json["status"] as String,
      createdById: json["created_by_id"] as String,
      createdByName: json["created_by_name"] as String,
      assignedToId: json["assigned_to_id"] as String?,
      assignedToName: json["assigned_to_name"] as String?,
      items: items,
      createdAt: DateTime.parse(json["created_at"] as String).toLocal(),
      updatedAt: DateTime.parse(json["updated_at"] as String).toLocal(),
    );
  }

  final String id;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? note;
  final String status;
  final String createdById;
  final String createdByName;
  final String? assignedToId;
  final String? assignedToName;
  final List<OrderItemModel> items;
  final DateTime createdAt;
  final DateTime updatedAt;
}
