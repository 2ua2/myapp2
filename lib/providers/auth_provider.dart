import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  // Role cached from SharedPreferences for guest child sessions (no Firebase Auth)
  String? _localRole;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null || _localRole != null;
  bool get isParent => _currentUser?.isParent ?? (_localRole == 'parent');
  bool get isChild => _currentUser?.isChild ?? (_localRole == 'child');

  AuthProvider() {
    _init();
    _loadLocalRole();
  }

  void _init() {
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        _currentUser = await _authService.getUserModel(user.uid);
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  // Restore guest child session from SharedPreferences on app start
  Future<void> _loadLocalRole() async {
    final prefs = await SharedPreferences.getInstance();
    _localRole = prefs.getString('user_role');
    notifyListeners();
  }

  Future<bool> signUpParent({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authService.signUpParent(
        name: name,
        email: email,
        password: password,
      );
      _currentUser = user;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authService.signIn(
        email: email,
        password: password,
      );
      _currentUser = user;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _currentUser = null;
      // Clear guest child session stored in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_role');
      await prefs.remove('family_id');
      await prefs.remove('child_id');
      _localRole = null;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
    }
    _setLoading(false);
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> sendChildVerificationCode(String parentEmail) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.sendChildVerificationCode(parentEmail);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  Future<bool> verifyChildCode(String parentEmail, String code) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.verifyChildCode(parentEmail, code);
      _localRole = 'child';
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  // Generates a 6-digit link code for the currently signed-in parent.
  // Returns null if the parent is not signed in or if generation fails.
  Future<String?> generateLinkCode() async {
    if (_currentUser == null) {
      _setError('You must be signed in to generate a code.');
      return null;
    }
    _setLoading(true);
    _clearError();
    try {
      final code = await _authService.generateLinkCode();
      _setLoading(false);
      return code;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return null;
    }
  }

  Future<bool> verifyLinkCode(String code, String childName) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.verifyLinkCode(code, childName);
      _localRole = 'child';
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      _setLoading(false);
      return false;
    }
  }

  void clearError() => _clearError();

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}