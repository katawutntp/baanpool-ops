/// Property model — maps to `properties` table in Supabase
class Property {
  final String id;
  final String name;
  final String? address;
  final String? ownerName;
  final String? ownerContact;
  final String? notes;
  final DateTime createdAt;

  const Property({
    required this.id,
    required this.name,
    this.address,
    this.ownerName,
    this.ownerContact,
    this.notes,
    required this.createdAt,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      ownerName: json['owner_name'] as String?,
      ownerContact: json['owner_contact'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'owner_name': ownerName,
    'owner_contact': ownerContact,
    'notes': notes,
  };
}
