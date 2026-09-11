import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class StaffService {
  static final StaffService _instance = StaffService._internal();
  factory StaffService() => _instance;
  StaffService._internal();

  // Base URL configuration (Supports Android Emulator 10.0.2.2 or localhost)
  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  String get wsBaseUrl {
    if (kIsWeb) return 'ws://localhost:8000';
    if (Platform.isAndroid) return 'ws://10.0.2.2:8000';
    return 'ws://localhost:8000';
  }

  String? _authToken;
  int? _staffUserId;
  int? _centreId;
  String? _username;
  String? _fullName;
  String? _role;

  String? get authToken => _authToken;
  int? get staffUserId => _staffUserId;
  int? get centreId => _centreId;
  String? get username => _username;
  String? get fullName => _fullName;
  String? get role => _role;
  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;

  void setSession({
    required String token,
    required int userId,
    required int centreId,
    required String username,
    required String fullName,
    required String role,
  }) {
    _authToken = token;
    _staffUserId = userId;
    _centreId = centreId;
    _username = username;
    _fullName = fullName;
    _role = role;
  }

  void logout() {
    _authToken = null;
    _staffUserId = null;
    _centreId = null;
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

  // Staff Login
  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/auth/staff-login');
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
      final token = data['access_token'];
      final userId = data['user_id'] ?? 1;
      final cId = data['centre_id'] ?? 1;
      final uName = data['username'] ?? username;
      final fName = data['full_name'] ?? 'Staff Operator';
      final uRole = data['role'] ?? 'CENTRE_STAFF';

      setSession(
        token: token,
        userId: userId,
        centreId: cId,
        username: uName,
        fullName: fName,
        role: uRole,
      );
      return data;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Staff login failed');
    }
  }

  // Dashboard Summary
  Future<Map<String, dynamic>> getDashboardSummary(int centreId) async {
    final url = Uri.parse('$baseUrl/staff/dashboard/$centreId');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load staff dashboard summary');
    }
  }

  // Today's Schedule
  Future<List<dynamic>> getSchedule(int centreId, {String? statusFilter}) async {
    String endpoint = '$baseUrl/staff/centre/$centreId/schedule';
    if (statusFilter != null && statusFilter.isNotEmpty) {
      endpoint += '?status_filter=$statusFilter';
    }
    final url = Uri.parse(endpoint);
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load today\'s schedule');
    }
  }

  // Active Counters
  Future<List<dynamic>> getCounters(int centreId) async {
    final url = Uri.parse('$baseUrl/staff/centre/$centreId/counters');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load counters');
    }
  }

  // Pause / Resume Centre
  Future<Map<String, dynamic>> pauseResumeCentre(int centreId, bool isPaused, String reason) async {
    final url = Uri.parse('$baseUrl/staff/centre/pause');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'centre_id': centreId,
        'is_paused': isPaused,
        'delay_reason': reason,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Failed to update centre pause status');
    }
  }

  // Toggle Counter Active
  Future<Map<String, dynamic>> toggleCounter(int counterId, bool isActive) async {
    final url = Uri.parse('$baseUrl/staff/counter/toggle');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'counter_id': counterId,
        'is_active': isActive,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to toggle counter status');
    }
  }

  // Mark Farmer Arrived
  Future<Map<String, dynamic>> markArrived(int bookingId) async {
    final url = Uri.parse('$baseUrl/queue/$bookingId/arrive');
    final response = await http.post(url, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Failed to mark farmer arrived');
    }
  }

  // Call Next Farmer
  Future<Map<String, dynamic>> callNextFarmer(int centreId, int counterId) async {
    final url = Uri.parse('$baseUrl/staff/queue/call-next');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'centre_id': centreId,
        'counter_id': counterId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'No waiting farmers in queue');
    }
  }

  // Verify Identity/Ticket
  Future<Map<String, dynamic>> verifyTicket(int bookingId, bool verified, {String? failureReason}) async {
    String endpoint = '$baseUrl/staff/procurement/$bookingId/verify?verified=$verified';
    if (failureReason != null && failureReason.isNotEmpty) {
      endpoint += '&failure_reason=${Uri.encodeComponent(failureReason)}';
    }
    final url = Uri.parse(endpoint);
    final response = await http.post(url, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update verification status');
    }
  }

  // Submit Quality Check
  Future<Map<String, dynamic>> submitQualityCheck({
    required int bookingId,
    required double moisturePercent,
    required double foreignMatterPercent,
    required double brokenGrainsPercent,
    required String grade,
    required bool passed,
    String? rejectionReason,
  }) async {
    final url = Uri.parse('$baseUrl/staff/procurement/$bookingId/quality-check');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'moisture_content_percent': moisturePercent,
        'foreign_matter_percent': foreignMatterPercent,
        'broken_grains_percent': brokenGrainsPercent,
        'grade': grade,
        'passed': passed,
        'rejection_reason': rejectionReason,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Failed to submit quality check');
    }
  }

  // Submit Weighment
  Future<Map<String, dynamic>> submitWeighment({
    required int bookingId,
    required double grossWeightKg,
    required double tareWeightKg,
    required int bagsCount,
  }) async {
    final url = Uri.parse('$baseUrl/staff/procurement/$bookingId/weighment');
    final response = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'gross_weight_kg': grossWeightKg,
        'tare_weight_kg': tareWeightKg,
        'bags_count': bagsCount,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Failed to submit weighment');
    }
  }

  // Complete Procurement
  Future<Map<String, dynamic>> completeProcurement(int bookingId) async {
    final url = Uri.parse('$baseUrl/staff/procurement/$bookingId/complete');
    final response = await http.post(url, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Failed to complete procurement');
    }
  }

  // Daily Summary
  Future<Map<String, dynamic>> getDailySummary(int centreId) async {
    final url = Uri.parse('$baseUrl/staff/summary/$centreId');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load daily summary');
    }
  }

  // WebSocket Live Queue Connection
  WebSocketChannel connectLiveQueueWebSocket(int centreId) {
    final wsUrl = Uri.parse('$wsBaseUrl/ws/queue/$centreId');
    return WebSocketChannel.connect(wsUrl);
  }
}
