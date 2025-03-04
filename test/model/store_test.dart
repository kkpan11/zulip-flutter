import 'dart:async';

import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';
import 'package:zulip/model/store.dart';

import '../api/fake_api.dart';
import '../example_data.dart' as eg;
import 'test_store.dart';

void main() {
  final account1 = eg.selfAccount.copyWith(id: 1);
  final account2 = eg.otherAccount.copyWith(id: 2);

  test('GlobalStore.perAccount sequential case', () async {
    final accounts = [account1, account2];
    final globalStore = LoadingTestGlobalStore(accounts: accounts);
    List<Completer<PerAccountStore>> completers(int accountId) =>
      globalStore.completers[accounts[accountId - 1]]!;

    final future1 = globalStore.perAccount(1);
    final store1 = PerAccountStore.fromInitialSnapshot(
      account: account1,
      connection: FakeApiConnection.fromAccount(account1),
      initialSnapshot: eg.initialSnapshot(),
    );
    completers(1).single.complete(store1);
    check(await future1).identicalTo(store1);
    check(await globalStore.perAccount(1)).identicalTo(store1);
    check(completers(1)).length.equals(1);

    final future2 = globalStore.perAccount(2);
    final store2 = PerAccountStore.fromInitialSnapshot(
      account: account2,
      connection: FakeApiConnection.fromAccount(account2),
      initialSnapshot: eg.initialSnapshot(),
    );
    completers(2).single.complete(store2);
    check(await future2).identicalTo(store2);
    check(await globalStore.perAccount(2)).identicalTo(store2);
    check(await globalStore.perAccount(1)).identicalTo(store1);

    // Only one loadPerAccount call was made per account.
    check(completers(1)).length.equals(1);
    check(completers(2)).length.equals(1);
  });

  test('GlobalStore.perAccount concurrent case', () async {
    final accounts = [account1, account2];
    final globalStore = LoadingTestGlobalStore(accounts: accounts);
    List<Completer<PerAccountStore>> completers(int accountId) =>
      globalStore.completers[accounts[accountId - 1]]!;

    final future1a = globalStore.perAccount(1);
    final future1b = globalStore.perAccount(1);
    // These should produce just one loadPerAccount call.
    check(completers(1)).length.equals(1);

    final future2 = globalStore.perAccount(2);
    final store1 = PerAccountStore.fromInitialSnapshot(
      account: account1,
      connection: FakeApiConnection.fromAccount(account1),
      initialSnapshot: eg.initialSnapshot(),
    );
    final store2 = PerAccountStore.fromInitialSnapshot(
      account: account2,
      connection: FakeApiConnection.fromAccount(account2),
      initialSnapshot: eg.initialSnapshot(),
    );
    completers(1).single.complete(store1);
    completers(2).single.complete(store2);
    check(await future1a).identicalTo(store1);
    check(await future1b).identicalTo(store1);
    check(await future2).identicalTo(store2);
    check(await globalStore.perAccount(1)).identicalTo(store1);
    check(await globalStore.perAccount(2)).identicalTo(store2);
    check(completers(1)).length.equals(1);
    check(completers(2)).length.equals(1);
  });

  test('GlobalStore.perAccountSync', () async {
    final accounts = [account1, account2];
    final globalStore = LoadingTestGlobalStore(accounts: accounts);
    List<Completer<PerAccountStore>> completers(int accountId) =>
      globalStore.completers[accounts[accountId - 1]]!;

    check(globalStore.perAccountSync(1)).isNull();
    final future1 = globalStore.perAccount(1);
    check(globalStore.perAccountSync(1)).isNull();
    final store1 = PerAccountStore.fromInitialSnapshot(
      account: account1,
      connection: FakeApiConnection.fromAccount(account1),
      initialSnapshot: eg.initialSnapshot(),
    );
    completers(1).single.complete(store1);
    await pumpEventQueue();
    check(globalStore.perAccountSync(1)).identicalTo(store1);
    check(await future1).identicalTo(store1);
    check(globalStore.perAccountSync(1)).identicalTo(store1);
    check(await globalStore.perAccount(1)).identicalTo(store1);
    check(completers(1)).length.equals(1);
  });
}

class LoadingTestGlobalStore extends TestGlobalStore {
  LoadingTestGlobalStore({required super.accounts});

  Map<Account, List<Completer<PerAccountStore>>> completers = {};

  @override
  Future<PerAccountStore> loadPerAccount(Account account) {
    final completer = Completer<PerAccountStore>();
    (completers[account] ??= []).add(completer);
    return completer.future;
  }
}
