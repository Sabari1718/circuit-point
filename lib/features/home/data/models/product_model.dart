class ProductModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String brand;
  final String category;
  final double offerPrice;
  final double mrp;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.brand,
    required this.category,
    required this.offerPrice,
    required this.mrp,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id']?.toString() ?? '',
      name: json['product_name'] ?? json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
      brand: json['brands'] ?? 'IMPORTED',
      category: json['categories'] ?? '',
      offerPrice: double.tryParse(json['selling_price']?.toString() ?? json['price']?.toString() ?? '0') ?? 0.0,
      mrp: double.tryParse(json['mrp']?.toString() ?? '0') ?? 0.0,
    );
  }
}
