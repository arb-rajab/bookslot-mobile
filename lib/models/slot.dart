class Slot {
  const Slot({
    required this.staffId,
    required this.startsAt,
    required this.endsAt,
  });

  factory Slot.fromJson(Map<String, dynamic> json) {
    return Slot(
      staffId: json['staff_id'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
    );
  }

  final String staffId;
  final DateTime startsAt;
  final DateTime endsAt;
}
