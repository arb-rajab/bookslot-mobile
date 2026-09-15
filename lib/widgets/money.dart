/// Formats an amount in minor currency units (cents), matching how
/// bookslot's API represents every monetary field.
String formatMinorUnits(int minorUnits, String currency) =>
    '${(minorUnits / 100).toStringAsFixed(2)} ${currency.toUpperCase()}';
