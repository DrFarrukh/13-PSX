/// Financial data models and CSV loader for the PSX Financial App.
library;

import 'package:flutter/services.dart';
import 'package:csv/csv.dart';

// ─────────────────── Data Classes ───────────────────

class CompanySnapshot {
  final double currentPrice;
  final double volume;
  final double dividend;
  final double dividendYield;
  final double bookValue;
  final double marketCap;
  final double debtToEquity;
  final double netProfitMargin;
  final double grossProfitMargin;
  final double currentRatio;
  final double shares;
  final double freeFloatPercent;
  final double equityToAsset;
  final double interestCover;
  final double beta;
  final double high52w;
  final double low52w;

  const CompanySnapshot({
    required this.currentPrice,
    required this.volume,
    required this.dividend,
    required this.dividendYield,
    required this.bookValue,
    required this.marketCap,
    required this.debtToEquity,
    required this.netProfitMargin,
    required this.grossProfitMargin,
    required this.currentRatio,
    required this.shares,
    required this.freeFloatPercent,
    required this.equityToAsset,
    required this.interestCover,
    required this.beta,
    required this.high52w,
    required this.low52w,
  });
}

class PayoutRecord {
  final String year;
  final String type;
  final double faceValue;
  final double payoutPercent;

  const PayoutRecord({
    required this.year,
    required this.type,
    required this.faceValue,
    required this.payoutPercent,
  });
}

/// A matrix dataset: metric name → list of values (one per year, oldest first).
typedef MetricMatrix = Map<String, List<double>>;

class FinancialDataset {
  final CompanySnapshot snapshot;
  final List<String> years;
  final MetricMatrix incomeStatement;
  final MetricMatrix balanceSheet;
  final MetricMatrix cashFlow;
  final MetricMatrix ratios;
  final List<PayoutRecord> payouts;

  const FinancialDataset({
    required this.snapshot,
    required this.years,
    required this.incomeStatement,
    required this.balanceSheet,
    required this.cashFlow,
    required this.ratios,
    required this.payouts,
  });
}

// ─────────────────── CSV Loader ───────────────────

class FinancialDataLoader {
  static Future<FinancialDataset> load() async {
    final snapshot = await _loadSnapshot();
    final (incYears, incData) = await _loadMatrix('assets/financial_data/income_statement.csv');
    final (_, bsData) = await _loadMatrix('assets/financial_data/balance_sheet.csv');
    final (_, cfData) = await _loadMatrix('assets/financial_data/cash_flow.csv');
    final (_, ratData) = await _loadMatrix('assets/financial_data/financial_ratios.csv');
    final payouts = await _loadPayouts();

    return FinancialDataset(
      snapshot: snapshot,
      years: incYears,
      incomeStatement: incData,
      balanceSheet: bsData,
      cashFlow: cfData,
      ratios: ratData,
      payouts: payouts,
    );
  }

  static Future<CompanySnapshot> _loadSnapshot() async {
    final raw = await rootBundle.loadString('assets/financial_data/company_snapshot.csv');
    final rows = const CsvToListConverter().convert(raw);
    final headers = rows[0].map((e) => e.toString()).toList();
    final values = rows[1];

    double get(String key) {
      final idx = headers.indexOf(key);
      if (idx < 0) return 0.0;
      return _toDouble(values[idx]);
    }

    return CompanySnapshot(
      currentPrice: get('Current'),
      volume: get('Volume'),
      dividend: get('Dividend'),
      dividendYield: get('Dividend_Yield'),
      bookValue: get('Book_Value'),
      marketCap: get('Market_Cap'),
      debtToEquity: get('Debt_to_Equity'),
      netProfitMargin: get('Net_Profit_Margin'),
      grossProfitMargin: get('Gross_Profit_Margin'),
      currentRatio: get('Current_Ratio'),
      shares: get('Shares'),
      freeFloatPercent: get('Free_Float_Percent'),
      equityToAsset: get('Equity_to_Asset'),
      interestCover: get('Interest_Cover'),
      beta: get('Beta'),
      high52w: get('52W_High'),
      low52w: get('Low'),
    );
  }

  static Future<(List<String>, MetricMatrix)> _loadMatrix(String path) async {
    final raw = await rootBundle.loadString(path);
    final rows = const CsvToListConverter().convert(raw);
    final header = rows[0].map((e) => e.toString()).toList();
    final years = header.sublist(1); // skip "Metric" column

    final MetricMatrix data = {};
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;
      final metric = row[0].toString();
      final values = <double>[];
      for (int j = 1; j < row.length && j < header.length; j++) {
        values.add(_toDouble(row[j]));
      }
      data[metric] = values;
    }
    return (years, data);
  }

  static Future<List<PayoutRecord>> _loadPayouts() async {
    final raw = await rootBundle.loadString('assets/financial_data/payouts.csv');
    final rows = const CsvToListConverter().convert(raw);
    final payouts = <PayoutRecord>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 4) continue;
      payouts.add(PayoutRecord(
        year: row[0].toString().substring(0, 4),
        type: row[1].toString(),
        faceValue: _toDouble(row[2]),
        payoutPercent: _toDouble(row[3]),
      ));
    }
    return payouts;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '')) ?? 0.0;
  }
}
