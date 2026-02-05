class SwitchSummary {
  final int id;
  final String name;

  SwitchSummary({
    required this.id,
    required this.name,
  });

  factory SwitchSummary.fromJson(Map<String, dynamic> json) {
    return SwitchSummary(
      id: json['switch_id'],
      name: json['name'],
    );
  }
}
