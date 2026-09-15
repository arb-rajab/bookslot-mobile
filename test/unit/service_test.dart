import 'package:bookslot_mobile/models/service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Service.estimatedDepositAmount', () {
    test('returns the fixed deposit amount when deposit_type is fixed', () {
      final service = Service.fromJson({
        'id': 's1',
        'name': 'Small Tattoo Session',
        'duration_minutes': 60,
        'price_amount': 20000,
        'currency': 'usd',
        'deposit_type': 'fixed',
        'deposit_fixed_amount': 5000,
        'deposit_percentage_bps': null,
        'buffer_before_minutes': 0,
        'buffer_after_minutes': 15,
      });

      expect(service.estimatedDepositAmount(), 5000);
    });

    test('computes a percentage deposit the same way bookslot\'s MandateRenderer does', () {
      final service = Service.fromJson({
        'id': 's2',
        'name': 'Large Piece',
        'duration_minutes': 180,
        'price_amount': 50000,
        'currency': 'usd',
        'deposit_type': 'percentage',
        'deposit_fixed_amount': null,
        'deposit_percentage_bps': 2500, // 25%
        'buffer_before_minutes': 0,
        'buffer_after_minutes': 30,
      });

      expect(service.estimatedDepositAmount(), 12500);
    });

    test('rounds a percentage deposit the same way (round, not truncate)', () {
      final service = Service.fromJson({
        'id': 's3',
        'name': 'Odd Amount',
        'duration_minutes': 45,
        'price_amount': 999,
        'currency': 'usd',
        'deposit_type': 'percentage',
        'deposit_fixed_amount': null,
        'deposit_percentage_bps': 3333,
        'buffer_before_minutes': 0,
        'buffer_after_minutes': 0,
      });

      // 999 * 3333 / 10000 = 332.9667 -> rounds to 333
      expect(service.estimatedDepositAmount(), 333);
    });

    test('returns 0 when deposit configuration is missing entirely', () {
      final service = Service.fromJson({
        'id': 's4',
        'name': 'Misconfigured',
        'duration_minutes': 30,
        'price_amount': 1000,
        'currency': 'usd',
        'deposit_type': 'fixed',
        'deposit_fixed_amount': null,
        'deposit_percentage_bps': null,
        'buffer_before_minutes': 0,
        'buffer_after_minutes': 0,
      });

      expect(service.estimatedDepositAmount(), 0);
    });
  });
}
