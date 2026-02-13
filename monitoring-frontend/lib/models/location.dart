class Location {
  final int id;
  final double latitude;
  final double longitude;
  final String? address;
  final String? type;
  final String name;
  final String? description;

  Location({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.address,
    this.type,
    required this.name,
    this.description,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['location_id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      address: json['address'],
      type: json['location_type'],
      description: json['description'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'location_type': type,
      'description': description,
    };
  }
}
