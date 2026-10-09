import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/user.dart';

/// Notifier global: nilainya dinaikkan setiap kali user login/logout.
/// RootRouter mendengarkan notifier ini untuk re-render halaman.
final ValueNotifier<int> authChanged = ValueNotifier<int>(0);

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  static const _kUserId = 'auth_user_id';
  static const _kRole = 'auth_role';
  static const _kUsername = 'auth_username';
  static const _kMemberId = 'auth_member_id';

  User? _current;
  User? get currentUser => _current;

  Future<User?> login({
    required String username,
    required String password,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username.trim(), password],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final user = User.fromMap(rows.first);
    await _saveSession(user);
    _current = user;
    authChanged.value++;
    return user;
  }

  Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUserId, user.id ?? 0);
    await prefs.setString(_kRole, roleToString(user.role));
    await prefs.setString(_kUsername, user.username);
    if (user.memberId != null) {
      await prefs.setInt(_kMemberId, user.memberId!);
    } else {
      await prefs.remove(_kMemberId);
    }
  }

  Future<User?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_kUsername);
    final roleStr = prefs.getString(_kRole);
    if (username == null || roleStr == null) return null;
    final user = User(
      id: prefs.getInt(_kUserId),
      username: username,
      password: '',
      role: roleFromString(roleStr),
      memberId: prefs.getInt(_kMemberId),
    );
    _current = user;
    return user;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _current = null;
    authChanged.value++;
  }
}