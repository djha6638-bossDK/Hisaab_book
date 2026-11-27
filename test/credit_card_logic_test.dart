import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_book/domain/credit_card_logic.dart';
import 'package:hisaab_book/models/credit_card_entry.dart';

void main() {
  CreditCardEntry entry({
    required CreditCardEntryType type,
    required double amount,
    DateTime? date,
  }) {
    return CreditCardEntry(
      id: 'entry',
      type: type,
      amount: amount,
      description: 'Test entry',
      date: date ?? DateTime(2026, 11, 27),
      createdAt: DateTime(2026, 11, 27, 10),
    );
  }

  group('CreditCardSummary', () {
    test('spend aur payment alag totals me judte hain', () {
      final summary = CreditCardSummary.fromEntries(<CreditCardEntry>[
        entry(type: CreditCardEntryType.spend, amount: 5555),
        entry(type: CreditCardEntryType.spend, amount: 445),
        entry(type: CreditCardEntryType.payment, amount: 4000),
      ]);

      expect(summary.totalSpend, 6000);
      expect(summary.totalPaid, 4000);
      expect(summary.outstanding, 2000);
      expect(summary.isSettled, isFalse);
    });

    test('payment spend se zyada hone par summary settled hoti hai', () {
      final summary = CreditCardSummary.fromEntries(<CreditCardEntry>[
        entry(type: CreditCardEntryType.spend, amount: 5555),
        entry(type: CreditCardEntryType.payment, amount: 5555),
      ]);

      expect(summary.outstanding, 0);
      expect(summary.isSettled, isTrue);
      expect(summary.hasEntries, isTrue);
    });
  });

  group('CreditCardEntry', () {
    test(
      'map round-trip type, amount, description aur date preserve karta hai',
      () {
        final original = CreditCardEntry(
          id: 'card-1',
          type: CreditCardEntryType.payment,
          amount: 4000,
          description: 'Card bill',
          date: DateTime(2026, 11, 26),
          createdAt: DateTime(2026, 11, 26, 20, 30),
        );

        final restored = CreditCardEntry.fromMap(
          'card-1',
          Map<String, dynamic>.from(original.toMap()),
        );

        expect(restored.type, CreditCardEntryType.payment);
        expect(restored.amount, 4000);
        expect(restored.description, 'Card bill');
        expect(restored.date, DateTime(2026, 11, 26));
        expect(restored.createdAt, DateTime(2026, 11, 26, 20, 30));
      },
    );

    test('unknown type spend me fallback hota hai', () {
      final restored = CreditCardEntry.fromMap('card-2', <String, dynamic>{
        'type': 'unknown',
        'amount': 150,
        'description': 'Chai',
        'date': '2026-11-27',
      });

      expect(restored.type, CreditCardEntryType.spend);
      expect(restored.displayDescription, 'Chai');
    });
  });

  test('creditCardDateId valid date ko parse karta hai', () {
    final date = DateTime(2026, 2, 28);

    expect(creditCardDateId(date), '2026-02-28');
    expect(parseCreditCardDateId('2026-02-28'), date);
    expect(parseCreditCardDateId('2026-02-30'), isNull);
  });
}
