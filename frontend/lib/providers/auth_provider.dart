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
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password, {String? gameName}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await api.register(
        username: username,
        email: email,
        password: password,
        gameInGameName: gameName,
      );
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await api.logout();
    _user = null;
    notifyListeners();
  }
}