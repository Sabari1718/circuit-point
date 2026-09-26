class SubSectorModel {
  final String id;
  final int sectorId;
  final String name;
  final String subSectorName;
  final String description;
  final String imageUrl;

  SubSectorModel({
    required this.id,
    required this.sectorId,
    required this.name,
    required this.subSectorName,
    required this.description,
    required this.imageUrl,
  });

  factory SubSectorModel.fromJson(Map<String, dynamic> json) {
    return SubSectorModel(
      id: json['id']?.toString() ?? '',
      sectorId: json['sector_id'] is int ? json['sector_id'] : int.tryParse(json['sector_id']?.toString() ?? '') ?? 0,
      name: json['name'] ?? '',
      subSectorName: json['sub_sector_name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
    );
  }
}

