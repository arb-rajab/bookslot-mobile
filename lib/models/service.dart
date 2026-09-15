class Service {
  const Service({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.priceAmount,
    required this.currency,
    required this.depositType,
    this.depositFixedAmount,
    this.depositPercentageBps,
    required this.bufferBeforeMinutes,
    required this.bufferAfterMinutes,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'] as String,
      name: json['name'] as String,
      durationMinutes: json['duration_minutes'] as int,
      priceAmount: json['price_amount'] as int,
      currency: json['currency'] as String,
      depositType: json['deposit_type'] as String,
      depositFixedAmount: json['deposit_fixed_amount'] as int?,
      depositPercentageBps: json['deposit_percentage_bps'] as int?,
      bufferBeforeMinutes: json['buffer_before_minutes'] as int,
      bufferAfterMinutes: json['buffer_after_minutes'] as int,
    );
  }

  final String id;
  final String name;
  final int durationMinutes;

  /// Minor currency units (cents), matching bookslot's `price_amount`.
  final int priceAmount;
  final String currency;
  final String depositType;
  final int? depositFixedAmount;
  final int? depositPercentageBps;
  final int bufferBeforeMinutes;
  final int bufferAfterMinutes;

  /// Mirrors the server's own deposit computation described in
  /// bookslot's `MandateRenderer` — this is only used for display before
  /// booking; the server-rendered mandate is always the source of truth
  /// for the actual charged amount.
  int estimatedDepositAmount() {
    if (depositType == 'fixed' && depositFixedAmount != null) {
      return depositFixedAmount!;
    }
    if (depositType == 'percentage' && depositPercentageBps != null) {
      return (priceAmount * depositPercentageBps! / 10000).round();
    }
    return 0;
  }
}
