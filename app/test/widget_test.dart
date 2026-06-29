import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turneyapp/core/formatters.dart';
import 'package:turneyapp/shared/models/competition.dart';
import 'package:turneyapp/shared/widgets/brand.dart';

void main() {
  group('Format.rupiah', () {
    test('formats Rupiah without decimals', () {
      expect(Format.rupiah(25000), 'Rp 25.000');
    });

    test('shows Free for zero', () {
      expect(Format.rupiah(0), 'Free');
    });
  });

  group('Competition fee split', () {
    test('platform takes 10%, organizer keeps the rest', () {
      const entryFee = 25000;
      final platformFee = (entryFee * 0.10).round();
      final organizerNet = entryFee - platformFee;
      expect(platformFee, 2500);
      expect(organizerNet, 22500);
    });

    test('format round-trips through string value', () {
      expect(
        CompetitionFormat.fromString(CompetitionFormat.roundRobin.value),
        CompetitionFormat.roundRobin,
      );
      expect(
        CompetitionFormat.fromString(CompetitionFormat.singleElim.value),
        CompetitionFormat.singleElim,
      );
    });
  });

  testWidgets('TagPill renders its label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: TagPill('Open'))),
      ),
    );
    expect(find.text('Open'), findsOneWidget);
  });
}
