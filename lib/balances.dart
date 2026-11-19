import 'dart:math';

class Debt {
  final String from;
  final String to;
  final int amount;
  Debt( this.from, this.to, this.amount);
}
class Balances {
  static Map<String, int> compute(
      Map<String, int> paid, Map<String, int> shares) {
    final result = <String, int>{};
    for ( final uid in {...paid.keys,...shares.keys}){
      result[uid] = (  paid [uid] ?? 0) - ( shares[uid] ?? 0);
    }
    return result;
  }
  static List<Debt> settle( Map<String, int> balances ){
    final bal = Map<String, int>.from(balances);
    final debts = <Debt>[];
    while ( true) {
      final nonZero = bal.entries.where((e) => e.value !=0).toList();
      if ( nonZero.isEmpty) break;
      nonZero.sort((a, b) => a.value.compareTo(b.value));
      final debtor = nonZero.first;
      final creditor = nonZero.last;
      final amount = debtor.value.abs() < creditor.value ? debtor.value.abs() : creditor.value;
      debts.add(Debt(debtor.key, creditor.key, amount));
      bal[ debtor.key] = debtor.value + amount;
      bal[ creditor.key ] = creditor.value - amount; }
     return debts;
    }
}