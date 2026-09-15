import 'package:flutter/material.dart';
import '../config/api.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService api;
  User? _user;
  bool _loading = false;
  String? _error;

  AuthProvider(this.api);

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<bool> tryAutoLogin() async {
    await apiClient.loadTokens();
    if (!apiClient.isAuthenticated) return false;
    try {
      _user = await api.getMe();
      notifyListeners();
      return true;
    } catch (_) {
      await apiClient.clearTokens();
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await api.login(username, password);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // A 401 from the login endpoint usually means the credentials were wrong,
      // so say that plainly instead of dumping DRF's raw detail string. The one
      // exception is an account that registered but never confirmed its code —
      // the backend flags that case explicitly so we can point the user at the
      // right fix (see ACCOUNT_NOT_VERIFIED_MESSAGE server-side).
      if (e is ApiException && e.statusCode == 401) {
        final detail = e.firstFieldError ?? e.message;
        _error = detail.toLowerCase().contains('not been verified')
            ? detail
            : 'Invalid username or password.';
      } else {
        _error = _messageFor(e);
      }
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// True when the last failure was an unverified account rather than bad
  /// credentials, so the login screen can offer a "verify now" shortcut.
  bool get lastErrorNeedsVerification =>
      (_error ?? '').toLowerCase().contains('not been verified');

  /// Register, returning the backend payload.
  ///
  /// Registration is a two-step handshake: the backend creates the account and
  /// issues a one-time code. The caller must send the user to the OTP screen
  /// with the returned `username` before they can sign in.
  Future<Map<String, dynamic>?> register(String username, String email, String password, {
    String? gameUid,
    String? gameInGameName,
    String? phoneNumber,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final payload = await api.register(
        username: username,
        email: email,
        password: password,
        gameUid: gameUid,
        gameInGameName: gameInGameName,
        phoneNumber: phoneNumber,
      );
      _loading = false;
      notifyListeners();
      return payload;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return null;
    }
  }

  /// Confirm the registration code. Returns true once the account is active.
  Future<bool> verifyOtp(String username, String code) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await api.verifyOtp(username: username, code: code);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _messageFor(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Ask for a fresh code. Returns the payload so the caller can surface
  /// `dev_otp` when the server has no mail transport configured.
  Future<Map<String, dynamic>?> resendOtp(String username, {String purpose = 'EMAIL_VERIFY'}) async {
    try {
      return await api.resendOtp(username: username, purpose: purpose);
    } catch (e) {
      _error = _messageFor(e);
      notifyListeners();
      return null;
    }
  }

  /// Start a password reset. Returns the payload (which carries `dev_otp` in
  /// development).
  Future<Map<String, dynamic>?> forgotPassword(String identifier) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final payload = await api.forgotPassword(identifier);
      _loading = false;
      notifyListeners();
      return payload;
    } catch (e) {
      _error = _messageFor(e);
      _loading = false;
      notifyListeners();
      return null;
    }
  }

  /// Complete a password reset with the issued code.
  Future<bool> resetPassword(String identifier, String code, String newPassword) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await api.resetPassword(
        identifier: identifier,
        code: code,
        newPassword: newPassword,
      );
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _messageFor(e);
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Pull the human-readable line out of a DRF error envelope.
  String _messageFor(Object e) {
    if (e is ApiException) {
      return e.firstFieldError ?? e.message;
    }
    return e.toString();
  }

  Future<void> logout() async {
    await api.logout();
    _user = null;
    notifyListeners();
  }
}