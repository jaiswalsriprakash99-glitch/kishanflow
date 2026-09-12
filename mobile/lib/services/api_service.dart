import 'dart:io';
import 'dart:convert';
import 'dart:async';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Android emulator connects to host via 10.0.2.2:8000
  String baseUrl = 'http://10.0.2.2:8000';
  String wsBaseUrl = 'ws://10.0.2.2:8000';

  String? _authToken;
  String? _adminUsername;
  String? _adminFullName;
  String? _adminRole;

  // In-memory Farmer session state
  String? _farmerToken;
  int? _farmerId;
  String? _farmerPhone;

  bool get isAuthenticated => _authToken != null && (_adminRole == 'ADMIN' || _adminRole == 'SUPER_ADMIN');
  String? get adminUsername => _adminUsername;
  String? get adminFullName => _adminFullName;
  String? get adminRole => _adminRole;
  String? get authToken => _authToken;

  bool get isFarmerAuthenticated => _farmerToken != null;
  String? get farmerToken => _farmerToken;
  int? get farmerId => _farmerId;
  String? get farmerPhone => _farmerPhone;

  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 8);

  void setBaseUrl(String url) {
    baseUrl = url.trim();
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    wsBaseUrl = baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
  }

  // ----------------- HTTP Helpers -----------------

  Future<dynamic> _get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final request = await _client.getUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      final token = _authToken ?? _farmerToken;
      if (token != null) {
        request.headers.set('Authorization', 'Bearer $token');
      }
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(body);
      } else {
        String errorDetail = 'HTTP ${response.statusCode}';
        try {
          final errJson = jsonDecode(body);
          if (errJson is Map && errJson.containsKey('detail')) {
            errorDetail = errJson['detail'].toString();
          }
        } catch (_) {}
        throw HttpException(errorDetail, uri: uri);
      }
    } on SocketException catch (_) {
      throw const SocketException('Unable to reach KisanFlow backend server (10.0.2.2:8000). Ensure backend is running.');
    }
  }

  Future<dynamic> _post(String path, Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final request = await _client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      final token = _authToken ?? _farmerToken;
      if (token != null) {
        request.headers.set('Authorization', 'Bearer $token');
      }
      request.write(jsonEncode(data));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(body);
      } else {
        String errorDetail = 'HTTP ${response.statusCode}';
        try {
          final errJson = jsonDecode(body);
          if (errJson is Map && errJson.containsKey('detail')) {
            errorDetail = errJson['detail'].toString();
          }
        } catch (_) {}
        throw HttpException(errorDetail, uri: uri);
      }
    } on SocketException catch (_) {
      throw const SocketException('Unable to reach KisanFlow backend server (10.0.2.2:8000). Ensure backend is running.');
    }
  }

  // ----------------- Authentication -----------------

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _post('/auth/staff-login', {
      'username': username.trim(),
      'password': password.trim(),
    });

    final role = res['role'] as String? ?? '';
    if (role != 'ADMIN' && role != 'SUPER_ADMIN') {
      throw const HttpException('Access denied. This portal is restricted to Administrator roles.');
    }

    _authToken = res['access_token'] as String;
    _adminRole = role;
    _adminUsername = username.trim();
    _adminFullName = username.trim() == 'admin' ? 'Chief Procurement Administrator' : username;

    return res as Map<String, dynamic>;
  }

  void logout() {
    _authToken = null;
    _adminRole = null;
    _adminUsername = null;
    _adminFullName = null;
  }

  // ----------------- Admin API Calls -----------------

  Future<Map<String, dynamic>> getDashboardStats() async {
    final res = await _get('/admin/dashboard-stats');
    return res as Map<String, dynamic>;
  }

  Future<List<dynamic>> getCentres() async {
    final res = await _get('/admin/centres');
    return res as List<dynamic>;
  }

  Future<Map<String, dynamic>> getCentreDetails(int centreId) async {
    final res = await _get('/admin/centres/$centreId');
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCentreStatus(
    int centreId, {
    bool? isActive,
    bool? isPaused,
    String? delayReason,
    bool? emergencyClosure,
  }) async {
    final res = await _post('/admin/centres/$centreId/status', {
      if (isActive != null) 'is_active': isActive,
      if (isPaused != null) 'is_paused': isPaused,
      if (delayReason != null) 'delay_reason': delayReason,
      if (emergencyClosure != null) 'emergency_closure': emergencyClosure,
    });
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCentreCounters(
    int centreId, {
    int? counterId,
    int? counterNumber,
    required bool isActive,
  }) async {
    final res = await _post('/admin/centres/$centreId/counters', {
      if (counterId != null) 'counter_id': counterId,
      if (counterNumber != null) 'counter_number': counterNumber,
      'is_active': isActive,
    });
    return res as Map<String, dynamic>;
  }

  Future<List<dynamic>> search(String query) async {
    final encoded = Uri.encodeComponent(query.trim());
    final res = await _get('/admin/search?query=$encoded');
    return res as List<dynamic>;
  }

  Future<Map<String, dynamic>> getPACSOverview() async {
    final res = await _get('/admin/pacs-overview');
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProcurementAnalytics() async {
    final res = await _get('/admin/analytics/procurement');
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPaymentAnalytics() async {
    final res = await _get('/admin/analytics/payments');
    return res as Map<String, dynamic>;
  }

  Future<List<dynamic>> getAlerts() async {
    final res = await _get('/admin/alerts');
    return res as List<dynamic>;
  }

  Future<Map<String, dynamic>> getModelInfo() async {
    final res = await _get('/admin/model-info');
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPredictedVsActual({int? centreId}) async {
    final q = centreId != null ? '?centre_id=$centreId' : '';
    final res = await _get('/admin/analytics/predicted-vs-actual$q');
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getReports() async {
    final res = await _get('/admin/reports');
    return res as Map<String, dynamic>;
  }

  Future<List<dynamic>> getAuditLogs({int limit = 30}) async {
    final res = await _get('/admin/audit-logs?limit=$limit');
    return res as List<dynamic>;
  }

  // Safe fallback polling for real-time queues
  Future<List<dynamic>> getCentreQueue(int centreId) async {
    try {
      final res = await _get('/queue/resync/$centreId');
      if (res is Map && res.containsKey('active_queue')) {
        return res['active_queue'] as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  // WebSocket Live Queue Connection with Ping Keepalive
  Future<WebSocket?> connectQueueWebSocket(
    int centreId, {
    required Function(dynamic message) onMessage,
    required Function(dynamic error) onError,
    required Function() onDone,
  }) async {
    if (_authToken == null) return null;
    try {
      final wsUri = Uri.parse('$wsBaseUrl/ws/centre/$centreId?token=$_authToken');
      final ws = await WebSocket.connect(wsUri.toString()).timeout(const Duration(seconds: 5));
      ws.listen(
        (data) {
          try {
            final parsed = jsonDecode(data.toString());
            onMessage(parsed);
          } catch (_) {
            onMessage(data);
          }
        },
        onError: onError,
        onDone: onDone,
      );
      return ws;
    } catch (e) {
      onError(e);
      return null;
    }
  }

  // ----------------- Farmer Authentication -----------------

  Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    final res = await _post('/auth/send-otp', {
      'phone_number': phoneNumber.trim(),
    });
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otp) async {
    final res = await _post('/auth/verify-otp', {
      'phone_number': phoneNumber.trim(),
      'otp': otp.trim(),
    });
    _farmerToken = res['access_token'] as String?;
    _farmerId = res['user_id'] as int?;
    _farmerPhone = phoneNumber.trim();
    return res as Map<String, dynamic>;
  }

  void logoutFarmer() {
    _farmerToken = null;
    _farmerId = null;
    _farmerPhone = null;
  }

  // ----------------- Farmer Slot & Booking APIs -----------------

  Future<List<dynamic>> getRankedCentres({String? cropType}) async {
    String path = '/centres';
    if (cropType != null && cropType.isNotEmpty) {
      path += '?crop_type=${Uri.encodeComponent(cropType)}';
    }
    final res = await _get(path);
    return res as List<dynamic>;
  }

  Future<List<dynamic>> getCentreSlots(int centreId, {int? cropId, String? date}) async {
    String path = '/centres/$centreId/slots';
    List<String> params = [];
    if (cropId != null) params.add('crop_id=$cropId');
    if (date != null && date.isNotEmpty) params.add('date=$date');
    if (params.isNotEmpty) {
      path += '?${params.join('&')}';
    }
    final res = await _get(path);
    return res as List<dynamic>;
  }

  Future<Map<String, dynamic>> createBooking({
    required int slotId,
    required int cropId,
    required double quantityQuintals,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'slot_id': slotId,
      'crop_id': cropId,
      'estimated_quantity_quintals': quantityQuintals,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    };
    final res = await _post('/bookings', body);
    return res as Map<String, dynamic>;
  }
}

