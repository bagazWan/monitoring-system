class Location {
  final int id;
  final double latitude;
  final double longitude;
  final String? address;
  final String name;
  final String? description;

  Location({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.address,
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
      description: json['description'],
    );
  }
}
