/// Asset model — maps to `assets` table in Supabase
class Asset {
  final String id;
  final String propertyId;
  final String name;
  final String? category; // e.g. HVAC, Plumbing, Electrical
  final String? brand;
  final String? model;
  final DateTime? installDate;
  final DateTime? warrantyExpiry;
  final String? notes;
  final String? imageUrl;
  final DateTime createdAt;

  const Asset({
    required this.id,
    required this.propertyId,
    required this.name,
    this.category,
    this.brand,
    this.model,
    this.installDate,
    this.warrantyExpiry,
    this.notes,
    this.imageUrl,
    required this.createdAt,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as String,
      propertyId: json['property_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      installDate: json['install_date'] != null
          ? DateTime.parse(json['install_date'] as String)
          : null,
      warrantyExpiry: json['warranty_expiry'] != null
          ? DateTime.parse(json['warranty_expiry'] as String)
          : null,
      notes: json['notes'] as String?,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'property_id': propertyId,
    'name': name,
    'category': category,
    'brand': brand,
    'model': model,
    'install_date': installDate?.toIso8601String(),
    'warranty_expiry': warrantyExpiry?.toIso8601String(),
    'notes': notes,
    'image_url': imageUrl,
  };

  bool get isWarrantyExpired =>
      warrantyExpiry != null && warrantyExpiry!.isBefore(DateTime.now());
}
