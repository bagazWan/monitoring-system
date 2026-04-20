class Location {
  final int id;
  final double latitude;
  final double longitude;
  final String? address;
  final String? type;
  final String name;
  final String? description;
  final int? groupId;
  final String? groupName;
  final String? typeLabel;

  Location(
      {required this.id,
      required this.latitude,
      required this.longitude,
      this.address,
      this.type,
      required this.name,
      this.description,
      this.groupId,
      this.groupName,
      this.typeLabel});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['location_id'],
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      address: json['address'],
      type: json['location_type'],
      description: json['description'],
      groupId: json['group_id'],
      groupName: json['group_name'],
      typeLabel: json['location_type_label'],
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

class LocationGroup {
  final int groupId;
  final String name;
  final String? description;

  LocationGroup({
    required this.groupId,
    required this.name,
    this.description,
  });

  factory LocationGroup.fromJson(Map<String, dynamic> json) {
    return LocationGroup(
      groupId: json['group_id'],
      name: json['name'],
      description: json['description'],
    );
  }
}

class LocationPage {
  final List<Location> items;
  final int total;
  final int page;
  final int pageSize;

  LocationPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory LocationPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List? ?? [];
    return LocationPage(
      items: raw.map((e) => Location.fromJson(e)).toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 10,
    );
  }
}
