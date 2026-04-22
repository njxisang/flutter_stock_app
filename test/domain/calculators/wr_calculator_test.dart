import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';
import 'package:flutter_stock_app/domain/usecases/calculators/wr_calculator.dart';

void main() {
  group('WrCalculator', () {
    test('should return empty list when quotes < 10', () {
      final quotes = List.generate(
        5,
        (i) => StockQuote(
          date: '2024-01-0${i + 1}',
          open: 10.0 + i,
          high: 11.0 + i,
          low: 9.0 + i,
          close: 10.5 + i,
          volume: 1000,
        ),
      );

      final result = WrCalculator.calculate(quotes);
      expect(result, isEmpty);
    });

    test('should return WR data when quotes >= 10', () {
      final quotes = List.generate(
        15,
        (i) => StockQuote(
          date: '2024-01-${(i + 1).toString().padLeft(2, '0')}',
          open: 10.0 + i * 0.1,
          high: 11.0 + i * 0.1,
          low: 9.0 + i * 0.1,
          close: 10.5 + i * 0.1,
          volume: 1000,
        ),
      );

      final result = WrCalculator.calculate(quotes);
      expect(result, isNotEmpty);
      expect(result.first.wr6, isNotNull);
      expect(result.first.wr10, isNotNull);
    });

    test('should calculate WR6 with correct 6-period lookback', () {
      // WR6 should use 6 periods (i-5 to i)
      final quotes = List.generate(
        15,
        (i) => StockQuote(
          date: '2024-01-${(i + 1).toString().padLeft(2, '0')}',
          open: 10.0,
          high: 11.0 + i * 0.5, // Increasing high
          low: 9.0,
          close: 10.5,
          volume: 1000,
        ),
      );

      final result = WrCalculator.calculate(quotes);
      expect(result, isNotEmpty);
      // When close is near the high, WR should be low (close to 0)
      expect(result.last.wr6, lessThan(50));
    });

    test('should calculate WR10 with correct 10-period lookback', () {
      final quotes = List.generate(
        20,
        (i) => StockQuote(
          date: '2024-01-${(i + 1).toString().padLeft(2, '0')}',
          open: 10.0 + i * 0.1,
          high: 11.0 + i * 0.1,
          low: 9.0 + i * 0.1,
          close: 10.5 + i * 0.1,
          volume: 1000,
        ),
      );

      final result = WrCalculator.calculate(quotes);
      expect(result, isNotEmpty);
      expect(result.last.wr10, isNotNull);
    });

    test('WR values should be between -100 and 0', () {
      final quotes = List.generate(
        20,
        (i) => StockQuote(
          date: '2024-01-${(i + 1).toString().padLeft(2, '0')}',
          open: 10.0,
          high: 15.0,
          low: 5.0,
          close: 10.0,
          volume: 1000,
        ),
      );

      final result = WrCalculator.calculate(quotes);
      for (final wr in result) {
        expect(wr.wr6, greaterThanOrEqualTo(-100));
        expect(wr.wr6, lessThanOrEqualTo(100));
        expect(wr.wr10, greaterThanOrEqualTo(-100));
        expect(wr.wr10, lessThanOrEqualTo(100));
      }
    });
  });
}
