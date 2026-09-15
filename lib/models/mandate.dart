/// Mirrors bookslot's `MandateRenderer` output (`GET
/// /tenants/{slug}/services/{service}/mandate`) — the server-rendered
/// consent text the customer must see before accepting the deposit
/// mandate. The app never renders its own mandate copy.
class Mandate {
  const Mandate({
    required this.text,
    required this.templateVersion,
    required this.balanceAmountDisclosed,
  });

  factory Mandate.fromJson(Map<String, dynamic> json) {
    return Mandate(
      text: json['text'] as String,
      templateVersion: json['template_version'] as String,
      balanceAmountDisclosed: json['balance_amount_disclosed'] as int,
    );
  }

  final String text;
  final String templateVersion;
  final int balanceAmountDisclosed;
}
