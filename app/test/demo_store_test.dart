import 'package:flutter_test/flutter_test.dart';
import 'package:turneyapp/core/demo_store.dart';
import 'package:turneyapp/shared/models/match.dart';

void main() {
  GameMatch humanMatch(DemoStore store, String compId, String uid) {
    return store.matchesFor(compId).firstWhere(
        (m) => m.round == 1 && (m.player1Id == uid || m.player2Id == uid));
  }

  test('register → generate → report → resolve completes the match', () {
    final store = DemoStore();
    addTearDown(store.dispose);
    final comp = store.competitions.firstWhere((c) => c.id == 'demo-1');

    store.register(comp.id, 'u1', 'Alice');
    store.closeAndGenerate(comp.id, 'u1');

    final matches = store.matchesFor(comp.id);
    expect(matches.length, 3); // 4 players → size 4 → 2 + 1

    final hm = humanMatch(store, comp.id, 'u1');
    store.reportResult(
      matchId: hm.id,
      reporterId: 'u1',
      reporterName: 'Alice',
      claimedWinnerId: 'u1',
    );
    store.resolveNow(hm.id);

    final resolved = store.matchById(hm.id)!;
    expect(resolved.status, MatchStatus.completed);
    expect(resolved.winnerId, 'u1');
  });

  test('conflicting reports open a dispute that a manager resolves', () {
    final store = DemoStore();
    addTearDown(store.dispose);
    final comp = store.competitions.firstWhere((c) => c.id == 'demo-1');

    store.register(comp.id, 'u1', 'Alice');
    store.closeAndGenerate(comp.id, 'u1');
    final hm = humanMatch(store, comp.id, 'u1');

    store.reportResult(
      matchId: hm.id,
      reporterId: 'u1',
      reporterName: 'Alice',
      claimedWinnerId: 'u1',
      simulateDispute: true, // bot reports itself → conflict
    );
    store.resolveNow(hm.id);
    expect(store.matchById(hm.id)!.status, MatchStatus.disputed);
    expect(store.disputedMatches, isNotEmpty);

    store.resolveDispute(hm.id, 'u1');
    final resolved = store.matchById(hm.id)!;
    expect(resolved.status, MatchStatus.completed);
    expect(resolved.winnerId, 'u1');
  });
}
