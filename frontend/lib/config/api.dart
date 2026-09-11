import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

const String defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000/api',
);

/// SharedPreferences key holding a user-chosen server URL.
const String apiBaseUrlPrefKey = 'api_base_url';

/// Strip whitespace and trailing slashes so path joins stay clean.
String normalizeBaseUrl(String url) => url.trim().replaceAll(RegExp(r'/+$'), '');

String _activeApiBaseUrl = normalizeBaseUrl(defaultApiBaseUrl);

/// The base URL every request uses right now.
String get apiBaseUrl => _activeApiBaseUrl;

/// True when the app is pointed at something other than the build-time default.
bool get hasCustomApiBaseUrl =>
    _activeApiBaseUrl != normalizeBaseUrl(defaultApiBaseUrl);

/// Restore a saved override. Called once from main() before the app starts.
Future<void> loadApiBaseUrl() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(apiBaseUrlPrefKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _activeApiBaseUrl = normalizeBaseUrl(saved);
    }
  } catch (_) {
    // No stored override — keep the compile-time default.
  }
}

/// Point the app at a different backend and remember it across restarts.
Future<void> setApiBaseUrl(String url) async {
  _activeApiBaseUrl = normalizeBaseUrl(url);
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(apiBaseUrlPrefKey, _activeApiBaseUrl);
  } catch (_) {}
}

/// Drop the override and fall back to the build-time default.
Future<void> resetApiBaseUrl() async {
  _activeApiBaseUrl = normalizeBaseUrl(defaultApiBaseUrl);
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(apiBaseUrlPrefKey);
  } catch (_) {}
}

class ApiClient {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null;

  Future<void> loadTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_accessKey);
      _refreshToken = prefs.getString(_refreshKey);
    } catch (_) {
      _accessToken = null;
      _refreshToken = null;
    }
  }

  Future<void> saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessKey, access);
      await prefs.setString(_refreshKey, refresh);
    } catch (_) {}
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessKey);
      await prefs.remove(_refreshKey);
    } catch (_) {}
  }

  Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_accessToken != null) {
      h['Authorization'] = 'Bearer $_accessToken';
    }
    return h;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        return _handleResponse(response);
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body.isEmpty) return {};
      return json.decode(body) as Map<String, dynamic>;
    }

    dynamic errorBody;
    try {
      errorBody = json.decode(body);
    } catch (_) {
      errorBody = {'detail': body};
    }

    String message = 'Request failed';
    if (errorBody is Map) {
      if (errorBody.containsKey('detail')) {
        message = errorBody['detail'].toString();
      } else if (errorBody.containsKey('error')) {
        message = errorBody['error'].toString();
      } else {
        message = errorBody.toString();
      }
    }
    throw ApiException(response.statusCode, message);
  }

  Future<Map<String, dynamic>> _handleListResponse(http.Response response) async {
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(body) as Map<String, dynamic>;
    }
    return _handleResponse(response).then((_) => {});
  }

  Future<bool> _tryRefreshToken() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh': _refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await saveTokens(data['access'], data['refresh'] ?? _refreshToken!);
        return true;
      }
    } catch (_) {}
    await clearTokens();
    return false;
  }

  /// Probe the currently configured server. Returns a human-readable result;
  /// used by the in-app server settings so users can fix a wrong URL without
  /// rebuilding the app.
  Future<String> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/health/'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        return 'Connected to $apiBaseUrl';
      }
      return 'Server replied HTTP ${response.statusCode}';
    } catch (_) {
      return 'Cannot reach $apiBaseUrl';
    }
  }

  Future<List<int>> getBytes(String path) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw ApiException(response.statusCode, utf8.decode(response.bodyBytes));
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getList(String path) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers,
    );
    return _handleListResponse(response);
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? data]) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers,
      body: data != null ? json.encode(data) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers,
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  Future<void> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, 'Delete failed');
    }
  }

  Future<String> uploadMultipart(String path, {
    required String filePath,
    required String fileName,
    required String mimeType,
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl$path'));
    if (_accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }
    if (fields != null) {
      request.fields.addAll(fields);
    }
    request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body;
    }
    throw ApiException(response.statusCode, response.body);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

final apiClient = ApiClient();