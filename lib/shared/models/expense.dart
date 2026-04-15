class Expense {
  const Expense({
    required this.date,
    required this.category,
    required this.amount,
    required this.payment,
  });

  final String date;
  final String category;
  final int amount;
  final String payment;
}