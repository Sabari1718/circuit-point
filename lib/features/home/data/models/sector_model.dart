class SectorModel {
  final int id;
  final int sectorTitleId;
  final String name;
  final String sectorName;
  final String description;
  final String imageUrl;

  SectorModel({
    required this.id,
    required this.sectorTitleId,
    required this.name,
    required this.sectorName,
    required this.description,
    required this.imageUrl,
  });

  factory SectorModel.fromJson(Map<String, dynamic> json) {
    return SectorModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      sectorTitleId: json['sector_title_id'] ?? 0,
      name: json['name'] ?? '',
      sectorName: json['sector_name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
    );
  }
}

