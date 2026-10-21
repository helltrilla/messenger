import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/saved_account.dart';

final accountLocalDataSourceProvider = Provider<AccountLocalDataSource>((ref) {
  return AccountLocalDataSourceImpl();
});

abstract class AccountLocalDataSource {
  Future<List<SavedAccount>> getSavedAccounts();
  Future<void> saveAccount(SavedAccount account);
  Future<void> removeAccount(String userId);
  Future<void> clearAll();
}

class AccountLocalDataSourceImpl implements AccountLocalDataSource {
  static const _storageKey = 'messenger_saved_accounts_v1';

  @override
  Future<List<SavedAccount>> getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list
          .map((item) => SavedAccount.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveAccount(SavedAccount account) async {
    final currentList = await getSavedAccounts();
    final index = currentList.indexWhere((a) => a.userId == account.userId);

    if (index >= 0) {
      currentList[index] = account;
    } else {
      currentList.add(account);
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(currentList.map((a) => a.toMap()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  @override
  Future<void> removeAccount(String userId) async {
    final currentList = await getSavedAccounts();
    currentList.removeWhere((a) => a.userId == userId);

    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(currentList.map((a) => a.toMap()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  @override
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
