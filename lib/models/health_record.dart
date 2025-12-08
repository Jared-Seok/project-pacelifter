class HealthRecord {
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final double? value;
  final String? unit;
  final String? sourceName;

  HealthRecord({
    required this.type,
    required this.startDate,
    required this.endDate,
    this.value,
    this.unit,
    this.sourceName,
  });

  factory HealthRecord.fromXml(Map<String, dynamic> attributes) {
    return HealthRecord(
      type: attributes['type'] ?? 'Unknown',
      startDate: DateTime.parse(attributes['startDate'] ?? ''),
      endDate: DateTime.parse(attributes['endDate'] ?? ''),
      value: attributes['value'] != null
          ? double.tryParse(attributes['value'])
          : null,
      unit: attributes['unit'],
      sourceName: attributes['sourceName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'value': value,
      'unit': unit,
      'sourceName': sourceName,
    };
  }

  @override
  String toString() {
    return '$type: $value $unit at ${startDate.toString()}';
  }
}
