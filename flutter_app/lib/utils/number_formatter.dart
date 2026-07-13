/// Number formatting utilities.
library;

import 'package:intl/intl.dart';

final _comma = NumberFormat('#,##0.00');

String formatNumber(double value, {int decimals = 2}) {
  final abs = value.abs();
  if (abs >= 1e9) return '${(value / 1e9).toStringAsFixed(decimals)} B';
  if (abs >= 1e6) return '${(value / 1e6).toStringAsFixed(decimals)} M';
  if (abs >= 1e3) return '${(value / 1e3).toStringAsFixed(decimals)} K';
  return value.toStringAsFixed(decimals);
}

String formatPkr(double value) => 'PKR ${_comma.format(value)}';

/// Returns the % change between consecutive values (NaN → 0).
double safePctChange(double prev, double curr) {
  if (prev == 0) return 0;
  return (curr - prev) / prev.abs() * 100;
}
