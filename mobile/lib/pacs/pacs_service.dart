import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PacsService {
  static final PacsService _instance = PacsService._internal();
  factory PacsService() => _instance;
  PacsService._internal();

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  String? _authToken;
  int? _pacsUserId;
  int? _pacsId;
  String? _pacsName;
  String? _pacsCode;
  String? _username;
  String? _fullName;
  String? _role;

  String? get authToken => _authToken;
  int? get pacsUserId => _pacsUserId;
  int? get pacsId => _pacsId;
  String? get pacsName => _pacsName;
  String? get pacsCode => _pacsCode;
  String? get username => _username;
  String? get fullName => _fullName;
  String? get role => _role;
  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;

  void setSession({
    required String token,
    required int userId,
    int? pacsId,
    String? pacsName,
    required String username,
    required String fullName,
    required String role,
  }) {
    _authToken = token;
    _pacsUserId = userId;
    _pacsId = pacsId ?? 1;
    _pacsName = pacsName ?? 'Mysore PACS';
    _username = username;
    _fullName = fullName;
    _role = role;
  }

  void logout() {
    _authToken = null;
    _pacsUserId = null;
    _pacsId = null;
    _pacsName = null;
    _pacsCode = null;
    _username = null;
    _fullName = null;
    _role = null;
  }

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/auth/staff-login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final role = data['role'] ?? 'PACS_OPERATOR';

        if (role != 'PACS_OPERATOR' && role != 'ADMIN' && role != 'SUPER_ADMIN') {
          return {
            'success': false,
            'message': 'Access Denied: Account is not a registered PACS Operator.',
          };
        }

        setSession(
          token: data['access_token'],
          userId: data['user_id'] ?? 1,
          pacsId: data['pacs_id'] ?? 1,
          pacsName: data['pacs_name'] ?? 'Mysore Primary Agricultural Credit Society',
          username: data['username'] ?? username,
          fullName: data['full_name'] ?? 'PACS Operator',
          role: role,
        );

        return {'success': true, 'data': data};
      } else {
        final err = jsonDecode(response.body);
        return {'success': false, 'message': err['detail'] ?? 'Invalid PACS operator credentials'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network connection failed: $e'};
    }
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    if (!isAuthenticated) return {'success': false, 'message': 'Not authenticated'};
    final url = Uri.parse('$baseUrl/pacs/dashboard-summary?pacs_id=${_pacsId ?? 1}');
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(res.body)};
      } else {
        final err = jsonDecode(res.body);
        return {'success': false, 'message': err['detail'] ?? 'Failed to load dashboard summary'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error loading dashboard: $e'};
    }
  }

  Future<List<dynamic>> searchFarmers(String query) async {
    if (!isAuthenticated) return [];
    final url = Uri.parse('$baseUrl/pacs/farmers/search?pacs_id=${_pacsId ?? 1}&query=${Uri.encodeComponent(query)}');
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
    } catch (e) {
      if (kDebugMode) print('Error searching farmers: $e');
    }
    return [];
  }

  Future<List<dynamic>> getDestinationCentres() async {
    if (!isAuthenticated) return [];
    final url = Uri.parse('$baseUrl/pacs/destination-centres');
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
    } catch (e) {
      if (kDebugMode) print('Error loading destination centres: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> createCollection({
    required int farmerId,
    required int cropId,
    required double quantityQuintals,
    double? totalAmount,
  }) async {
    if (!isAuthenticated) return {'success': false, 'message': 'Not authenticated'};
    final url = Uri.parse('$baseUrl/pacs/collection');
    try {
      final res = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'pacs_id': _pacsId ?? 1,
          'farmer_id': farmerId,
          'crop_id': cropId,
          'quantity_quintals': quantityQuintals,
          'total_amount': totalAmount,
        }),
      );

      if (res.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(res.body)};
      } else {
        final err = jsonDecode(res.body);
        return {'success': false, 'message': err['detail'] ?? 'Collection submission failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error submitting collection: $e'};
    }
  }

  Future<List<dynamic>> getPendingCollections() async {
    if (!isAuthenticated) return [];
    final url = Uri.parse('$baseUrl/pacs/pending?pacs_id=${_pacsId ?? 1}');
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
    } catch (e) {
      if (kDebugMode) print('Error loading pending collections: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> forwardCollection({
    required int procurementRecordId,
    required int destinationCentreId,
  }) async {
    if (!isAuthenticated) return {'success': false, 'message': 'Not authenticated'};
    final url = Uri.parse('$baseUrl/pacs/forward');
    try {
      final res = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'procurement_record_id': procurementRecordId,
          'destination_centre_id': destinationCentreId,
        }),
      );

      if (res.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(res.body)};
      } else {
        final err = jsonDecode(res.body);
        return {'success': false, 'message': err['detail'] ?? 'Forwarding failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error during forwarding: $e'};
    }
  }

  Future<List<dynamic>> getDispatches() async {
    if (!isAuthenticated) return [];
    final url = Uri.parse('$baseUrl/pacs/dispatches?pacs_id=${_pacsId ?? 1}');
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
    } catch (e) {
      if (kDebugMode) print('Error loading dispatches: $e');
    }
    return [];
  }

  Future<List<dynamic>> getPayments() async {
    if (!isAuthenticated) return [];
    final url = Uri.parse('$baseUrl/pacs/payments?pacs_id=${_pacsId ?? 1}');
    try {
      final res = await http.get(url, headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
    } catch (e) {
      if (kDebugMode) print('Error loading payments: $e');
    }
    return [];
  }
}
