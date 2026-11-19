import 'package:flutter_test/flutter_test.dart';
import 'package:depenses_partagees/money.dart';
import 'package:depenses_partagees/balances.dart';
void main() {
  group('Money', () {
    test('partage de 10000 entre 3', () {
      final parts = Money.splitEqually(10000, 3);
      expect(parts, [3334, 3333, 3333]);
      expect(parts.reduce((a, b) => a + b), 10000);
    });
    test('format', () {
      expect(Money.format(12500), '12,500 DT');
      expect(Money.format(47350), '47,350 DT');
      expect(Money.format(5), '0,005 DT');
    });
  });
  group('balances', () {
    test(' la somme des soldes est nulle', () {
      final paid = { 'ali': 30000};
      final shares = {'ali': 10000, 'sana': 10000, 'omar': 10000};
      final bal = Balances.compute(paid, shares);
      expect(bal['ali'], 20000);
      expect(bal['sana'], -10000);
      expect(bal['omar'], -10000);
      expect(bal.values.reduce((a, b) => a + b), 0);
    });
    test(' remboursement : au plus n-1', () {
      final bal = { 'ali': 20000, 'sana': -10000, 'omar': -10000};
      final debts = Balances.settle(bal);
      expect(debts.length, lessThanOrEqualTo(2));
      expect(debts.every((d) => d.to == 'ali'), true);
      expect(debts.fold<int>(0, (s, d) => s + d.amount), 20000);
    });
  });
}