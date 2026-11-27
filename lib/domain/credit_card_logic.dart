import '../models/credit_card_entry.dart';

class CreditCardSummary {
  const CreditCardSummary({required this.totalSpend, required this.totalPaid});

  factory CreditCardSummary.fromEntries(Iterable<CreditCardEntry> entries) {
    var totalSpend = 0.0;
    var totalPaid = 0.0;
    for (final entry in entries) {
      if (entry.isPayment) {
        totalPaid += entry.amount;
      } else {
        totalSpend += entry.amount;
      }
    }
    return CreditCardSummary(totalSpend: totalSpend, totalPaid: totalPaid);
  }

  final double totalSpend;
  final double totalPaid;

  double get outstanding => totalSpend - totalPaid;

  bool get hasEntries => totalSpend > 0 || totalPaid > 0;

  bool get isSettled => outstanding <= 0.005;
}
