class Money {
  static List<int> splitEqually(int total, int count) {
    final base = total ~/ count;
    final remainder = total % count;
    return List.generate(count, (i)=> i < remainder ? base + 1 : base);
  }
  static String format(int millimes) {
    final negative = millimes < 0;
    final abs = millimes.abs();
    final dinars = abs ~/ 1000;
    final rest = ( abs % 1000).toString().padLeft(3, '0');
    return '${negative ?'-': ''}$dinars,$rest DT';

  }
}