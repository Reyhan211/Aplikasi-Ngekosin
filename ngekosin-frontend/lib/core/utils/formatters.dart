/// 1200000 -> "Rp1.200.000"
String rupiah(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return 'Rp$b';
}

/// 1200000 -> "Rp1,2 jt", 850000 -> "Rp850 rb"
String rupiahShort(int v) {
  if (v >= 1000000) {
    final j = v / 1000000;
    final t = j == j.roundToDouble() ? j.toStringAsFixed(0) : j.toStringAsFixed(1);
    return 'Rp${t.replaceAll('.', ',')} jt';
  }
  if (v >= 1000) return 'Rp${(v / 1000).round()} rb';
  return 'Rp$v';
}

String typeLabel(String type) {
  switch (type) {
    case 'putra':
      return 'Putra';
    case 'putri':
      return 'Putri';
    default:
      return 'Campur';
  }
}

/// 1250 -> "1.250" (tanpa "Rp")
String thousands(int v) => rupiah(v.abs()).substring(2);
