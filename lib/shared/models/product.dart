class Product {
  const Product({
    required this.title,
    required this.category,
    required this.stock,
    required this.price,
    required this.badge,
  });

  final String title;
  final String category;
  final int stock;
  final int price;
  final String badge;
}