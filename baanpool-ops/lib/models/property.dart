/// Property model — maps to `properties` table in Supabase
class Property {
  final String id;
  final String name;
  final String? address;
  final String? ownerName;
  final String? ownerContact;
  final String? notes;
  final String? caretakerId;
  final String? caretakerName; // joined from users table
  final DateTime createdAt;

  const Property({
    required this.id,
    required this.name,
    this.address,
    this.ownerName,
    this.ownerContact,
    this.notes,
    this.caretakerId,
    this.caretakerName,
    required this.createdAt,
  });

  factory Property.fromJson(Map<String, dynamic> json) {
    // Handle joined caretaker user data
    String? ctName;
    if (json['caretaker'] is Map) {
      ctName = json['caretaker']['full_name'] as String?;
    }

    return Property(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      ownerName: json['owner_name'] as String?,
      ownerContact: json['owner_contact'] as String?,
      notes: json['notes'] as String?,
      caretakerId: json['caretaker_id'] as String?,
      caretakerName: ctName,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'owner_name': ownerName,
    'owner_contact': ownerContact,
    'notes': notes,
    'caretaker_id': caretakerId,
  };
}
