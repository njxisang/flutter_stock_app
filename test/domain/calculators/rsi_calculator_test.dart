import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_stock_app/domain/entities/stock_quote.dart';
import 'package:flutter_stock_app/domain/usecases/calculators/rsi_calculator.dart';

void main() {
  group('RsiCalculator', () {
    test('should return empty list when quotes < period + 1', () {
      final quotes = List.generate(
        10,
        (i) => StockQuote(
          date: '2024-01-${(i + 1).toString().padLeft(2, '0')}',
          open: 10.0 + i,
          high: 11.0 + i,
          low: 9.0 + i,
          close: 10.5 + i,
          volume: 1000,
        ),
      );

      final result = RsiCalculator.calculate(quotes);
      expect(result, isEmpty);
    });

    test('should calculate RSI values between 0 and 100', () {
      final quotes = List.generate(
        30,
        (i) => StockQuote(
          date: '2024-01-${(i + 1).toString().padLeft(2, '0')}',
          open: 10.0,
          high: 11.0,
          low: 9.0,
          close: 10.0 + (i % 2 == 0 ? 0.5 : -0.3), // Oscillating price
          volume: 1000,
        ),
      );

      final result = RsiCalculator.calculate(quotes);
      expect(result, isNotEmpty);
      for (final rsi in result) {
        expect(rsi.rsi, greaterThanOrEqualTo(0));
        expect(rsi.rsi, lessThanOrEqualTo(100));
      }
    });

    test('should return 100 when all price changes are positive', () {
      final quotes = List.generate(
        20,
        (i) => StockQuote(
          date: '2024-01-${(i + 1).toString().padLeft(2, '0')}',
          open: 10.0 + i,
          high: 11.0 + i,
          low: 9.0 + i,
          close: 10.5 + i, // Always increasing
          volume: 1000,
        ),
      );

      final result = RsiCalculator.calculate(quotes);
      expect(result.last.rsi, equals(100));
    });

    test('should return 0 when all price changes are negative', () {
      final quotes = List.generate(
        20,
        (i) => StockQuote(
          date: '2024-01-${(i + 1).toString().padLeft(2, '0')}',
          open: 20.0 - i,
          high: 21.0 - i,
          low: 19.0 - i,
          close: 20.5 - i, // Always decreasing
          volume: 1000,
        ),
      );

      final result = RsiCalculator.calculate(quotes);
      expect(result.last.rsi, equals(0));
    });
  });
}
