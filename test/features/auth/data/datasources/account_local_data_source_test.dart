import 'package:flutter_test/flutter_test.dart';
import 'package:messenger/features/auth/data/datasources/account_local_data_source.dart';
import 'package:messenger/features/auth/domain/entities/saved_account.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SavedAccount', () {
    test('serializes to and from Map correctly', () {
      const account = SavedAccount(
        userId: 'u1',
        email: 'test@example.com',
        displayName: 'Test User',
        username: 'testuser',
        avatarUrl: 'https://example.com/avatar.png',
        refreshToken: 'refresh123',
      );

      final map = account.toMap();
      final fromMap = SavedAccount.fromMap(map);

      expect(fromMap.userId, account.userId);
      expect(fromMap.email, account.email);
      expect(fromMap.displayName, account.displayName);
      expect(fromMap.username, account.username);
      expect(fromMap.avatarUrl, account.avatarUrl);
      expect(fromMap.refreshToken, account.refreshToken);
      expect(fromMap, account);
    });

    test('copyWith updates fields as expected', () {
      const account = SavedAccount(
        userId: 'u1',
        email: 'test@example.com',
        displayName: 'Old Name',
        username: 'olduser',
        refreshToken: 'token1',
      );

      final updated = account.copyWith(
        displayName: 'New Name',
        refreshToken: 'token2',
      );

      expect(updated.displayName, 'New Name');
      expect(updated.refreshToken, 'token2');
      expect(updated.email, account.email);
    });
  });

  group('AccountLocalDataSourceImpl', () {
    late AccountLocalDataSourceImpl dataSource;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dataSource = AccountLocalDataSourceImpl();
    });

    test('saves and retrieves accounts', () async {
      const account1 = SavedAccount(
        userId: 'u1',
        email: 'user1@example.com',
        displayName: 'User 1',
        username: 'user1',
        refreshToken: 'ref1',
      );
      const account2 = SavedAccount(
        userId: 'u2',
        email: 'user2@example.com',
        displayName: 'User 2',
        username: 'user2',
        refreshToken: 'ref2',
      );

      await dataSource.saveAccount(account1);
      await dataSource.saveAccount(account2);

      final accounts = await dataSource.getSavedAccounts();
      expect(accounts.length, 2);
      expect(accounts.map((a) => a.userId), containsAll(['u1', 'u2']));
    });

    test('updates existing account with same userId', () async {
      const account1 = SavedAccount(
        userId: 'u1',
        email: 'user1@example.com',
        displayName: 'User 1',
        username: 'user1',
        refreshToken: 'ref1',
      );
      const updatedAccount = SavedAccount(
        userId: 'u1',
        email: 'user1@example.com',
        displayName: 'Updated Name',
        username: 'user1',
        refreshToken: 'ref_new',
      );

      await dataSource.saveAccount(account1);
      await dataSource.saveAccount(updatedAccount);

      final accounts = await dataSource.getSavedAccounts();
      expect(accounts.length, 1);
      expect(accounts.first.displayName, 'Updated Name');
      expect(accounts.first.refreshToken, 'ref_new');
    });

    test('removes account by userId', () async {
      const account1 = SavedAccount(
        userId: 'u1',
        email: 'user1@example.com',
        displayName: 'User 1',
        username: 'user1',
        refreshToken: 'ref1',
      );
      await dataSource.saveAccount(account1);

      await dataSource.removeAccount('u1');
      final accounts = await dataSource.getSavedAccounts();
      expect(accounts, isEmpty);
    });

    test('clearAll removes all accounts', () async {
      const account1 = SavedAccount(
        userId: 'u1',
        email: 'user1@example.com',
        displayName: 'User 1',
        username: 'user1',
        refreshToken: 'ref1',
      );
      await dataSource.saveAccount(account1);

      await dataSource.clearAll();
      final accounts = await dataSource.getSavedAccounts();
      expect(accounts, isEmpty);
    });
  });
}
