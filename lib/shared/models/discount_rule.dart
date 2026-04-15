class DiscountRule {
  const DiscountRule({
    required this.service,
    required this.price,
    required this.duration,
    this.percent = 0,
    this.onlyNewClients = false,
  });

  final String service;
  final int price;
  final int duration;
  final int percent;
  final bool onlyNewClients;
}