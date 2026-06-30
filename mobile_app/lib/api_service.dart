import "dart:convert";
import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;

import "config.dart";
import "models.dart";

class StockApiService {
  static const Duration _requestTimeout = Duration(seconds: 18);
  static const String _loginTimeoutMessage =
      "Server is taking longer than usual. Please wait a moment and try again.";
  static const String _timeoutMessage =
      "เชื่อมต่อเซิร์ฟเวอร์ช้าเกินไป กรุณาตรวจสอบ backend แล้วลองใหม่";

  static String? _accessToken;

  void setAccessToken(String? value) {
    final trimmed = value?.trim();
    _accessToken = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  void clearAccessToken() {
    _accessToken = null;
  }

  String? get accessToken => _accessToken;

  Map<String, String> _headers([Map<String, String>? extra]) {
    final headers = <String, String>{};
    if (_accessToken != null) {
      headers["Authorization"] = "Bearer $_accessToken";
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse("${AppConfig.baseUrl}$path").replace(
      queryParameters: queryParameters,
    );
  }

  Uri websocketUri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse(AppConfig.baseUrl);
    return base.replace(
      scheme: base.scheme == "https" ? "wss" : "ws",
      path: path,
      queryParameters: queryParameters,
    );
  }

  Future<bool> isAssistantAvailable() async {
    try {
      final response = await _get("/health");
      final body = _decode(response) as Map<String, dynamic>;
      final features = body["features"] as Map<String, dynamic>?;
      return features?["assistant_chat"] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> _postLogin(Map<String, dynamic> payload) async {
    try {
      return await http
          .post(
            _uri("/auth/login"),
            headers: _headers({"Content-Type": "application/json"}),
            body: jsonEncode(payload),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
          "เชื่อมต่อเซิร์ฟเวอร์ช้าเกินไป กรุณาตรวจสอบ backend แล้วลองใหม่");
    }
  }

  Future<http.Response> _postLoginFriendly(Map<String, dynamic> payload) async {
    try {
      return await http
          .post(
            _uri("/auth/login"),
            headers: _headers({"Content-Type": "application/json"}),
            body: jsonEncode(payload),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(_loginTimeoutMessage);
    }
  }

  Future<http.Response> _get(
    String path, [
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  ]) async {
    try {
      return await http
          .get(_uri(path, queryParameters), headers: _headers(headers))
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
          "เชื่อมต่อเซิร์ฟเวอร์ช้าเกินไป กรุณาตรวจสอบ backend แล้วลองใหม่");
    }
  }

  Future<http.Response> _postJson(
    String path,
    Map<String, dynamic> payload, [
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  ]) async {
    try {
      return await http
          .post(
            _uri(path, queryParameters),
            headers: _headers({
              "Content-Type": "application/json",
              ...?headers,
            }),
            body: jsonEncode(payload),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
          "เชื่อมต่อเซิร์ฟเวอร์ช้าเกินไป กรุณาตรวจสอบ backend แล้วลองใหม่");
    }
  }

  Future<List<Product>> getProducts({bool lowStockOnly = false, bool includeInactive = false}) async {
    final response =
        await _get("/products", {
          "low_stock_only": lowStockOnly.toString(),
          "include_inactive": includeInactive.toString(),
        });
    final body = _decode(response);
    return (body as List<dynamic>)
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<http.Response> _patchJson(
    String path,
    Map<String, dynamic> payload, [
    Map<String, String>? queryParameters,
  ]) async {
    try {
      return await http
          .patch(
            _uri(path, queryParameters),
            headers: _headers({"Content-Type": "application/json"}),
            body: jsonEncode(payload),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
          "เชื่อมต่อเซิร์ฟเวอร์ช้าเกินไป กรุณาตรวจสอบ backend แล้วลองใหม่");
    }
  }

  Future<http.Response> _delete(
    String path, [
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  ]) async {
    try {
      return await http
          .delete(_uri(path, queryParameters), headers: _headers(headers))
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(
          "เชื่อมต่อเซิร์ฟเวอร์ช้าเกินไป กรุณาตรวจสอบ backend แล้วลองใหม่");
    }
  }

  Future<void> registerDeviceToken({
    required String requesterId,
    required String platform,
    required String token,
  }) async {
    await _postJson(
      "/devices/register",
      {
        "platform": platform,
        "token": token,
      },
      {"requester_id": requesterId},
      _headers(),
    );
  }

  Future<String> getNextBarcode() async {
    final response = await _get("/products/barcode/next");
    final body = _decode(response) as Map<String, dynamic>;
    return body["barcode"] as String? ?? "";
  }

  Future<List<AppUser>> getUsers({bool activeOnly = true}) async {
    final response =
        await _get("/users", {"active_only": activeOnly.toString()});
    final body = _decode(response);
    return (body as List<dynamic>)
        .map((item) => AppUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<LoginSession> login({
    required String userId,
    required String pin,
  }) async {
    final payload = {
      "user_id": userId,
      "pin": pin,
    };

    final response = await _postLoginFriendly(payload);
    final session =
        LoginSession.fromJson(_decode(response) as Map<String, dynamic>);
    setAccessToken(session.accessToken);
    return session;
  }

  Future<AppUser> getCurrentUser() async {
    final start = DateTime.now();
    final response = await _get("/auth/me");
    print("DEBUG TIMER: load current user duration = ${DateTime.now().difference(start).inMilliseconds} ms");
    return AppUser.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<AppUser> updateMyProfile({
    required String userName,
  }) async {
    final response = await _patchJson("/auth/profile", {
      "user_name": userName,
    });
    if (response.statusCode == 404) {
      throw Exception(
          "เชื่อมต่อเซิร์ฟเวอร์ช้าเกินไป กรุณาตรวจสอบ backend แล้วลองใหม่");
    }
    return AppUser.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _postJson("/auth/logout", {}, null, _headers());
    clearAccessToken();
  }

  Future<String> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final response = await _postJson(
      "/auth/change-pin",
      {
        "current_pin": currentPin,
        "new_pin": newPin,
      },
      null,
      _headers(),
    );
    final body = _decode(response) as Map<String, dynamic>;
    return body["message"] as String? ?? "PIN changed successfully.";
  }

  Future<AppUser> upsertUser({
    required String requesterId,
    required String userId,
    required String userName,
    String role = "staff",
    String? position,
    bool active = true,
    String? pin,
    String? profileImageUrl,
  }) async {
    final response = await _postJson(
      "/users/upsert",
      {
        "requester_id": requesterId,
        "user_id": userId,
        "user_name": userName,
        "role": role,
        "position": position,
        "active": active,
        "pin": pin,
        "profile_image_url": profileImageUrl,
      },
      null,
      _headers(),
    );
    return AppUser.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<String> deleteUser({
    required String requesterId,
    required String userId,
    bool deleteMovements = false,
  }) async {
    final response = await _delete(
      "/users/$userId",
      {
        "requester_id": requesterId,
        "delete_movements": deleteMovements.toString(),
      },
      _headers(),
    );
    final body = _decode(response) as Map<String, dynamic>;
    return body["message"] as String? ?? "Deleted user";
  }

  Future<String> deleteProduct({
    required String requesterId,
    required String barcode,
  }) async {
    final response = await _delete(
      "/products/${Uri.encodeComponent(barcode)}",
      {
        "requester_id": requesterId,
      },
      _headers(),
    );
    final body = _decode(response) as Map<String, dynamic>;
    return body["message"] as String? ?? "Product deleted successfully.";
  }

  Future<String> restoreProduct({
    required String requesterId,
    required String barcode,
  }) async {
    final response = await _postJson(
      "/products/${Uri.encodeComponent(barcode)}/restore",
      {},
      {
        "requester_id": requesterId,
      },
      _headers(),
    );
    final body = _decode(response) as Map<String, dynamic>;
    return body["message"] as String? ?? "กู้คืนสินค้าเรียบร้อยแล้ว";
  }

  Future<AppUser> uploadProfileImage({
    required String requesterId,
    required String targetUserId,
    String? filePath,
    List<int>? bytes,
    String? filename,
  }) async {
    final request = http.MultipartRequest(
      "POST",
      _uri("/users/upload-profile-image"),
    )
      ..headers.addAll(_headers())
      ..fields["requester_id"] = requesterId
      ..fields["target_user_id"] = targetUserId;

    if (bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          "image",
          bytes,
          filename: filename ?? "profile.jpg",
        ),
      );
    } else if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath("image", filePath));
    } else {
      throw Exception("Missing image payload.");
    }

    final streamed = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamed);
    return AppUser.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<Map<String, String>> ocrShippingLabel({
    required String requesterId,
    String? filePath,
  }) async {
    final uri = _uri("/ocr/shipping-label");
    final request = http.MultipartRequest("POST", uri)
      ..headers.addAll(_headers())
      ..fields["requester_id"] = requesterId;

    debugPrint("OCR HEADERS HAVE AUTH: ${request.headers.containsKey('Authorization')}");
    debugPrint("OCR REQUESTER ID PRESENT: ${request.fields.containsKey('requester_id')}");

    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath("image", filePath));
    } else {
      throw ArgumentError("filePath must be provided");
    }

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);

    // Let _decode handle non-200 status codes (it throws Exception with the detail)
    final decoded = _decode(response);
    if (decoded is Map) {
      return {
        "name": decoded["name"]?.toString() ?? "",
        "phone": decoded["phone"]?.toString() ?? "",
        "address": decoded["address"]?.toString() ?? "",
      };
    }
    throw Exception("Invalid OCR response format.");
  }

  String resolveAssetUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return "";
    }
    final value = rawUrl.trim();
    if (value.startsWith("http://") || value.startsWith("https://")) {
      return value;
    }
    final normalizedPath = value.startsWith("/") ? value : "/$value";
    return "${AppConfig.baseUrl}$normalizedPath";
  }

  Future<String> syncProducts({required String requesterId}) async {
    final response = await _postJson(
      "/integrations/google-sheets/sync/products",
      {},
      {"requester_id": requesterId},
      _headers(),
    );
    final body = _decode(response) as Map<String, dynamic>;
    return body["message"] as String? ?? "Synced products";
  }

  Future<String> syncUsers({required String requesterId}) async {
    final response = await _postJson(
      "/integrations/google-sheets/sync/users",
      {},
      {"requester_id": requesterId},
      _headers(),
    );
    final body = _decode(response) as Map<String, dynamic>;
    return body["message"] as String? ?? "Synced users";
  }

  Future<String> syncStocks({required String requesterId}) async {
    final response = await _postJson(
      "/integrations/google-sheets/sync/stocks",
      {},
      {"requester_id": requesterId},
      _headers(),
    );
    final body = _decode(response) as Map<String, dynamic>;
    return body["message"] as String? ?? "Synced stocks";
  }

  Future<String> appendTest({required String requesterId}) async {
    final response = await _postJson(
      "/integrations/google-sheets/append-test",
      {},
      {"requester_id": requesterId},
      _headers(),
    );
    final body = _decode(response) as Map<String, dynamic>;
    return body["message"] as String? ?? "Append test completed";
  }

  Future<String> importProductsExcel({
    required String requesterId,
    String? filePath,
    List<int>? bytes,
    String? filename,
  }) async {
    final request = http.MultipartRequest(
      "POST",
      _uri("/products/import-excel"),
    )..headers.addAll(_headers());

    request.fields["requester_id"] = requesterId;

    if (bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          bytes,
          filename: filename ?? "products.xlsx",
        ),
      );
    } else if (filePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          "file",
          filePath,
          filename: filename,
        ),
      );
    } else {
      throw Exception("Missing Excel file payload.");
    }

    final streamed = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamed);
    final body = _decode(response) as Map<String, dynamic>;
    return body["message"] as String? ?? "นำเข้า Excel สำเร็จ";
  }

  Future<ExportLink> createExportLink({
    required String exportName,
    required String requesterId,
    int movementLimit = 5000,
    String? barcode,
    String? actorId,
  }) {
    return _postJson(
      "/exports/link",
      {
        "export_name": exportName,
        "movement_limit": movementLimit,
        "barcode": barcode,
        "actor_id": actorId,
      },
      {"requester_id": requesterId},
      _headers(),
    ).then((response) {
      final body = _decode(response) as Map<String, dynamic>;
      final link = ExportLink.fromJson(body);
      final normalizedPath =
          link.url.startsWith("/") ? link.url : "/${link.url}";
      return ExportLink(
        url: "${AppConfig.baseUrl}$normalizedPath",
        expiresAt: link.expiresAt,
      );
    });
  }

  String exportUrl({
    required String path,
    required String requesterId,
    Map<String, String>? extraQuery,
  }) {
    final query = <String, String>{"requester_id": requesterId};
    if (extraQuery != null) {
      query.addAll(extraQuery);
    }
    return _uri(path, query).toString();
  }

  Future<StockSummary> getSummary() async {
    final response = await _get("/stock/summary");
    return StockSummary.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<List<MovementRecord>> getMovements({int limit = 30, String? reference}) async {
    final Map<String, String> params = {"limit": "$limit"};
    if (reference != null) {
      params["reference"] = reference;
    }
    final response = await _get("/movements", params);
    final body = _decode(response);
    return (body as List<dynamic>)
        .map((item) => MovementRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AppNotification>> getNotifications({int limit = 20}) async {
    final response = await _get("/notifications", {"limit": "$limit"});
    final body = _decode(response);
    return (body as List<dynamic>)
        .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ScanResult> submitScan({
    required String barcode,
    required String action,
    required int quantity,
    required String actorId,
    required String actorName,
    String? note,
    String? reference,
    bool autoCreateProduct = false,
    String? productName,
    String productUnit = "pcs",
    int productMinimumStock = 0,
    String? productCategory,
    String? productLocation,
    String? productSku,
  }) async {
    final response = await _postJson(
      "/scan",
      {
        "barcode": barcode,
        "action": action,
        "quantity": quantity,
        "actor_id": actorId,
        "actor_name": actorName,
        "note": note,
        "reference": reference,
        "auto_create_product": autoCreateProduct,
        "product_name": productName,
        "product_unit": productUnit,
        "product_minimum_stock": productMinimumStock,
        "product_category": productCategory,
        "product_location": productLocation,
        "product_sku": productSku,
      },
      null,
      _headers(),
    );
    return ScanResult.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<ChatAssistantResult> askAssistant({
    required String message,
  }) async {
    http.Response response;
    try {
      response = await _postJson(
        "/assistant/chat",
        {
          "message": message,
        },
        null,
        _headers(),
      );
    } catch (error) {
      final text = error.toString().toLowerCase();
      if (text.contains("not found")) {
        throw Exception(
            "เชื่อมต่อเซิร์ฟเวอร์ช้าเกินไป กรุณาตรวจสอบ backend แล้วลองใหม่");
      }
      rethrow;
    }
    final result =
        ChatAssistantResult.fromJson(_decode(response) as Map<String, dynamic>);
    final link = result.downloadLink;
    if (link == null) {
      return result;
    }
    final normalizedPath = link.url.startsWith("/") ? link.url : "/${link.url}";
    return ChatAssistantResult(
      message: result.message,
      matchedProducts: result.matchedProducts,
      aiEnabled: result.aiEnabled,
      usedAi: result.usedAi,
      action: result.action,
      downloadLink: ExportLink(
        url: "${AppConfig.baseUrl}$normalizedPath",
        expiresAt: link.expiresAt,
      ),
    );
  }

  Future<List<DeliveryOrder>> getOrders({
    required String requesterId,
    bool assignedOnly = false,
    bool mineOnly = false,
    int limit = 300,
  }) async {
    assert(() {
      debugPrint(
        "[api] getOrders requester=$requesterId token=${_accessToken == null ? 'null' : '${_accessToken!.substring(0, _accessToken!.length.clamp(0, 8))}...'}",
      );
      return true;
    }());
    final response = await _get(
      "/orders",
      {
        "requester_id": requesterId,
        "assigned_only": assignedOnly.toString(),
        "mine_only": mineOnly.toString(),
        "limit": limit.toString(),
      },
      _headers(),
    );
    final body = _decode(response);
    return (body as List<dynamic>)
        .map((item) => DeliveryOrder.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DeliveryOrder> createOrder({
    required String requesterId,
    required String customerName,
    String? customerPhone,
    String? customerAddress,
    String? note,
    String? assignedToId,
    String? productionUserId,
    String? qcUserId,
    String? deliveryUserId,
    DateTime? scheduledDeliveryAt,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _postJson(
      "/orders",
      {
        "customer_name": customerName,
        "customer_phone": customerPhone,
        "customer_address": customerAddress,
        "note": note,
        "assigned_to_id": assignedToId,
        "production_user_id": productionUserId,
        "qc_user_id": qcUserId,
        "delivery_user_id": deliveryUserId,
        "scheduled_delivery_at": scheduledDeliveryAt?.toUtc().toIso8601String(),
        "items": items,
      },
      {"requester_id": requesterId},
      _headers(),
    );
    return DeliveryOrder.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<DeliveryOrder> updateOrder({
    required String requesterId,
    required String orderId,
    required String customerName,
    String? customerPhone,
    String? customerAddress,
    String? note,
    String? assignedToId,
    String? productionUserId,
    String? qcUserId,
    String? deliveryUserId,
    DateTime? scheduledDeliveryAt,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _patchJson(
      "/orders/$orderId",
      {
        "customer_name": customerName,
        "customer_phone": customerPhone,
        "customer_address": customerAddress,
        "note": note,
        "assigned_to_id": assignedToId,
        "production_user_id": productionUserId,
        "qc_user_id": qcUserId,
        "delivery_user_id": deliveryUserId,
        "scheduled_delivery_at": scheduledDeliveryAt?.toUtc().toIso8601String(),
        "items": items,
      },
      {"requester_id": requesterId},
    );
    return DeliveryOrder.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<void> deleteOrder({
    required String requesterId,
    required String orderId,
  }) async {
    final response = await _delete(
      "/orders/$orderId",
      {"requester_id": requesterId},
      _headers(),
    );
    _decode(response);
  }

  Future<List<OrderMessageModel>> getOrderMessages({
    required String requesterId,
    required String orderId,
  }) async {
    final response = await _get(
      "/orders/$orderId/messages",
      {"requester_id": requesterId},
      _headers(),
    );
    final body = _decode(response) as Map<String, dynamic>;
    final items = body["items"] as List<dynamic>? ?? const [];
    return items
        .map((item) => OrderMessageModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<OrderMessageModel> postOrderMessage({
    required String requesterId,
    required String orderId,
    required String message,
  }) async {
    final response = await _postJson(
      "/orders/$orderId/messages",
      {"message": message},
      {"requester_id": requesterId},
      _headers(),
    );
    final body = _decode(response) as Map<String, dynamic>;
    final item = body["item"] as Map<String, dynamic>;
    return OrderMessageModel.fromJson(item);
  }

  Future<void> markOrderMessagesRead({
    required String requesterId,
    required String orderId,
  }) async {
    await _postJson(
      "/orders/$orderId/messages/read",
      const {},
      {"requester_id": requesterId},
      _headers(),
    );
  }

  Future<DeliveryOrder> assignOrder({
    required String requesterId,
    required String orderId,
    required String assignedToId,
  }) async {
    final response = await _postJson(
      "/orders/$orderId/assign",
      {
        "assigned_to_id": assignedToId,
      },
      {"requester_id": requesterId},
      _headers(),
    );
    return DeliveryOrder.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<DeliveryOrder> assignOrderTeam({
    required String requesterId,
    required String orderId,
    String? productionUserId,
    String? boardProductionUserId,
    String? robotProductionUserId,
    String? qcUserId,
    String? deliveryUserId,
  }) async {
    final response = await _postJson(
      "/orders/$orderId/team",
      {
        "production_user_id": productionUserId,
        "board_production_user_id": boardProductionUserId,
        "robot_production_user_id": robotProductionUserId,
        "qc_user_id": qcUserId,
        "delivery_user_id": deliveryUserId,
      },
      {"requester_id": requesterId},
      _headers(),
    );
    return DeliveryOrder.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<DeliveryOrder> updateOrderStatus({
    required String requesterId,
    required String orderId,
    required String status,
  }) async {
    final response = await _postJson(
      "/orders/$orderId/status",
      {
        "status": status,
      },
      {"requester_id": requesterId},
      _headers(),
    );
    return DeliveryOrder.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<DeliveryOrder> deliverOrderPartial({
    required String requesterId,
    required String orderId,
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    final response = await _postJson(
      "/orders/$orderId/deliver-partial",
      {
        "items": items,
        "note": note,
      },
      {"requester_id": requesterId},
      _headers(),
    );
    return DeliveryOrder.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<DeliveryOrder> resolveBackorder({
    required String requesterId,
    required String orderId,
  }) async {
    final response = await _postJson(
      "/orders/$orderId/resolve-backorder",
      const {},
      {"requester_id": requesterId},
      _headers(),
    );
    return DeliveryOrder.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<void> uploadOrderProofPhoto({
    required String requesterId,
    required String orderId,
    required String filePath,
  }) async {
    final request = http.MultipartRequest(
      "POST",
      _uri("/orders/$orderId/proof-photo"),
    )
      ..headers.addAll(_headers())
      ..fields["requester_id"] = requesterId
      ..files.add(await http.MultipartFile.fromPath("image", filePath));
    final streamed = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamed);
    _decode(response);
  }

  Future<List<String>> getOrderProofPhotos({
    required String requesterId,
    required String orderId,
  }) async {
    final response = await _get(
      "/orders/$orderId/proof-photos",
      {"requester_id": requesterId},
    );
    final body = _decode(response) as Map<String, dynamic>;
    final items = body["items"] as List<dynamic>? ?? [];
    return items
        .map((item) =>
            (item as Map<String, dynamic>)["photo_url"] as String? ?? "")
        .where((url) => url.isNotEmpty)
        .map(resolveAssetUrl)
        .toList();
  }

  String orderPrintUrl({
    required String orderId,
    required String requesterId,
  }) {
    return _uri("/orders/$orderId/print", {"requester_id": requesterId})
        .toString();
  }

  String orderPackingSlipUrl({
    required String orderId,
    required String requesterId,
  }) {
    return _uri("/orders/$orderId/packing-slip", {"requester_id": requesterId})
        .toString();
  }

  String orderPdfUrl({
    required String orderId,
    required String requesterId,
  }) {
    return _uri("/orders/$orderId/print.pdf", {"requester_id": requesterId})
        .toString();
  }

  Future<Uint8List> downloadBackup(String requesterId) async {
    final url = _uri("/admin/backup", {"requester_id": requesterId});
    debugPrint("Backup URL: $url");

    try {
      final response = await http
          .get(url, headers: _headers())
          .timeout(const Duration(minutes: 5)); // Backups can be large

      if (response.statusCode != 200) {
        String detail = "Failed to download backup: ${response.statusCode}";
        try {
          final decodedText = utf8.decode(response.bodyBytes);
          final body = jsonDecode(decodedText);
          if (body is Map<String, dynamic> && body.containsKey("detail")) {
            detail = "Failed to download backup: ${body["detail"]} (${response.statusCode})";
          } else {
            detail = "Failed to download backup: $decodedText (${response.statusCode})";
          }
        } catch (_) {
          final decodedText = utf8.decode(response.bodyBytes);
          if (decodedText.isNotEmpty) {
            detail = "Failed to download backup: $decodedText (${response.statusCode})";
          }
        }
        throw Exception(detail);
      }
      return response.bodyBytes;
    } on TimeoutException {
      throw Exception("Backup download timed out. The file might be too large or the server is busy.");
    }
  }

  Future<String> restoreBackup({
    required String requesterId,
    String? filePath,
    List<int>? bytes,
    String? filename,
  }) async {
    final request = http.MultipartRequest(
      "POST",
      _uri("/admin/restore"),
    )..headers.addAll(_headers());

    request.fields["requester_id"] = requesterId;

    if (bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          bytes,
          filename: filename ?? "backup.zip",
        ),
      );
    } else if (filePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          "file",
          filePath,
          filename: filename,
        ),
      );
    } else {
      throw Exception("Missing backup ZIP payload.");
    }

    final streamed = await request.send().timeout(const Duration(minutes: 3));
    final response = await http.Response.fromStream(streamed);
    final body = _decode(response) as Map<String, dynamic>;
    return body["message"] as String? ?? "Restore completed successfully.";
  }

  Future<List<ProductActivityLog>> getProductActivityLogs({
    String? barcode,
    String? action,
    int? limit,
    String? requesterId,
  }) async {
    final Map<String, String> queryParams = {};
    if (barcode != null) queryParams["barcode"] = barcode;
    if (action != null) queryParams["action"] = action;
    if (limit != null) queryParams["limit"] = limit.toString();
    if (requesterId != null) queryParams["requester_id"] = requesterId;

    final response = await _get("/products/activity", queryParams);
    final body = _decode(response);
    return (body as List<dynamic>)
        .map((item) => ProductActivityLog.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductTimelineItem>> getProductTimeline({
    required String barcode,
    required String requesterId,
    int limit = 100,
  }) async {
    final Map<String, String> queryParams = {
      "requester_id": requesterId,
      "limit": limit.toString(),
    };
    final response = await _get("/products/$barcode/timeline", queryParams);
    final body = _decode(response);
    return (body as List<dynamic>)
        .map((item) => ProductTimelineItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Object _decode(http.Response response) {
    final decodedText = utf8.decode(response.bodyBytes);
    final body = jsonDecode(decodedText);
    if (response.statusCode >= 400) {
      final detail = body is Map<String, dynamic> ? body["detail"] : null;
      throw Exception(detail ?? "Request failed with ${response.statusCode}");
    }
    return body;
  }
}
