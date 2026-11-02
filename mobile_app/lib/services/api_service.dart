import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService instance = ApiService._init();
  ApiService._init();

  static const String _prefKey = 'photocraft_api_url';
  static const String defaultWifiDevIp = 'http://192.168.1.5:8000';

  String _baseUrl = defaultBaseUrl();
  String get baseUrl => _baseUrl;

  final ValueNotifier<String> serverUrlNotifier = ValueNotifier<String>(defaultBaseUrl());
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);

  // Default fallback based on platform
  static String defaultBaseUrl() {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (Platform.isAndroid) return defaultWifiDevIp;
    return 'http://127.0.0.1:8000';
  }

  set baseUrl(String url) {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    serverUrlNotifier.value = _baseUrl;
    _saveToPrefs(_baseUrl);
  }

  Future<void> _saveToPrefs(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, url);
    } catch (e) {
      debugPrint('Error saving api url to prefs: $e');
    }
  }

  /// Initialize and automatically discover the active server on current Wi-Fi network
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefKey);
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _baseUrl = savedUrl;
        serverUrlNotifier.value = _baseUrl;
      }
    } catch (_) {}

    // Run auto-discovery in background without blocking startup
    autoDiscoverServer();
  }

  /// Probe a single target URL for /api/health
  Future<bool> _probe(String targetUrl, {Duration timeout = const Duration(milliseconds: 1500)}) async {
    try {
      final uri = Uri.parse('$targetUrl/api/health');
      final res = await http.get(uri).timeout(timeout);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is Map && data['status'] == 'healthy') {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Automatically discovers the backend on Wi-Fi or local network
  Future<bool> autoDiscoverServer() async {
    debugPrint('PhotoCraft: Bat dau tu dong tim may chu API tren mang...');

    // 1. First probe current baseUrl immediately
    if (await _probe(_baseUrl, timeout: const Duration(seconds: 1))) {
      debugPrint('PhotoCraft: Ket noi thanh cong toi URL hien tai: $_baseUrl');
      isConnectedNotifier.value = true;
      return true;
    }

    // 2. Build candidate list prioritizing Wi-Fi network
    final List<String> candidates = [];

    // Saved IP & Known Dev Wi-Fi IP
    candidates.add(defaultWifiDevIp);

    // Dynamic Wi-Fi subnet discovery
    if (!kIsWeb) {
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (var iface in interfaces) {
          for (var addr in iface.addresses) {
            final ip = addr.address;
            if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
              final parts = ip.split('.');
              if (parts.length == 4) {
                final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
                // Add common host IPs in the same subnet
                candidates.add('http://$prefix.5:8000');
                candidates.add('http://$prefix.1:8000');
                candidates.add('http://$prefix.2:8000');
                candidates.add('http://$prefix.3:8000');
                candidates.add('http://$prefix.4:8000');
                candidates.add('http://$prefix.6:8000');
                candidates.add('http://$prefix.7:8000');
                candidates.add('http://$prefix.8:8000');
                candidates.add('http://$prefix.100:8000');
                candidates.add('http://$prefix.101:8000');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Network interface probe error: $e');
      }
    }

    // Standard emulator & localhost fallbacks
    candidates.add('http://10.0.2.2:8000');
    candidates.add('http://127.0.0.1:8000');
    candidates.add('http://localhost:8000');

    // Deduplicate
    final uniqueCandidates = candidates.toSet().toList();

    // Probe in fast parallel batches of 4
    for (int i = 0; i < uniqueCandidates.length; i += 4) {
      final batch = uniqueCandidates.sublist(
        i,
        (i + 4 > uniqueCandidates.length) ? uniqueCandidates.length : i + 4,
      );

      final futures = batch.map((url) async {
        final ok = await _probe(url, timeout: const Duration(milliseconds: 1400));
        return ok ? url : null;
      });

      final results = await Future.wait(futures);
      for (var foundUrl in results) {
        if (foundUrl != null) {
          debugPrint('PhotoCraft: Da tim thay may chu API tai: $foundUrl');
          _baseUrl = foundUrl;
          serverUrlNotifier.value = foundUrl;
          isConnectedNotifier.value = true;
          await _saveToPrefs(foundUrl);
          return true;
        }
      }
    }

    isConnectedNotifier.value = false;
    debugPrint('PhotoCraft: Chua tim thay may chu API tren mang Wi-Fi.');
    return false;
  }

  Future<Map<String, dynamic>> checkHealth() async {
    final stopwatch = Stopwatch()..start();
    try {
      final uri = Uri.parse('$_baseUrl/api/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      stopwatch.stop();
      if (res.statusCode == 200) {
        isConnectedNotifier.value = true;
        return {
          'success': true,
          'latency': stopwatch.elapsedMilliseconds,
          'message': 'Kết nối thành công (${stopwatch.elapsedMilliseconds}ms)'
        };
      }
      isConnectedNotifier.value = false;
      return {
        'success': false,
        'latency': stopwatch.elapsedMilliseconds,
        'message': 'Server trả về mã ${res.statusCode}'
      };
    } catch (e) {
      stopwatch.stop();
      isConnectedNotifier.value = false;
      return {
        'success': false,
        'latency': 0,
        'message': 'Không thể kết nối API ($_baseUrl): $e'
      };
    }
  }

  Future<Uint8List> applyFilter({
    required Uint8List imageBytes,
    required String filterType,
    required double intensity,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/filter');
    final request = http.MultipartRequest('POST', uri);

    request.fields['filter_type'] = filterType;
    request.fields['intensity'] = intensity.toStringAsFixed(2);

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: 'upload.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 25));
    if (streamedResponse.statusCode == 200) {
      final response = await http.Response.fromStream(streamedResponse);
      return response.bodyBytes;
    } else {
      final errBody = await streamedResponse.stream.bytesToString();
      throw Exception('Lỗi API Filter (${streamedResponse.statusCode}): $errBody');
    }
  }

  Future<Uint8List> applySharpen({
    required Uint8List imageBytes,
    required String method,
    required double strength,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/sharpen');
    final request = http.MultipartRequest('POST', uri);

    request.fields['method'] = method;
    request.fields['strength'] = strength.toStringAsFixed(2);

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: 'upload.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 25));
    if (streamedResponse.statusCode == 200) {
      final response = await http.Response.fromStream(streamedResponse);
      return response.bodyBytes;
    } else {
      final errBody = await streamedResponse.stream.bytesToString();
      throw Exception('Lỗi API Sharpen (${streamedResponse.statusCode}): $errBody');
    }
  }
}
