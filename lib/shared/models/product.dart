class Product {
  const Product({
    required this.id,
    required this.title,
    required this.category,
    required this.stock,
    required this.price,
  });

  final int id;
  final String title;
  final String category;
  final int stock;
  final int price;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      title: json['title'] as String,
      category: json['category'] as String,
      stock: json['stock'] as int,
      price: json['price'] as int,
    );
  }
}
