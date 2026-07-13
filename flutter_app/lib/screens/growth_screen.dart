/// Growth vs Dividend categorization screen.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/financial_data.dart';
import '../utils/number_formatter.dart';
import '../widgets/section_card.dart';

class GrowthScreen extends StatelessWidget {
  final FinancialDataset data;
  const GrowthScreen({super.key, required this.data});

  double _avgGrowth(List<double> vals) {
    if (vals.length < 2) return 0;
    double sum = 0;
    for (int i = 1; i < vals.length; i++) {
      if (vals[i - 1] != 0) sum += (vals[i] - vals[i-1]) / vals[i-1].abs() * 100;
    }
    return sum / (vals.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final inc   = data.incomeStatement;
    final rat   = data.ratios;
    final years = data.years;

    final sales   = inc['Sales']        ?? [];
    final gp      = inc['Gross Profit'] ?? [];
    final pat     = inc['PAT']          ?? [];
    final eps     = inc['EPS']          ?? [];
    final roe     = rat['Return on Equity']  ?? [];
    final nm      = rat['Net Profit Margin'] ?? [];

    final revenueGrowth = _avgGrowth(sales);
    final profitGrowth  = _avgGrowth(pat);
    final epsGrowth     = _avgGrowth(eps);

    // Dividend metrics
    final divYield = data.snapshot.dividendYield;
    final payoutRatio = rat['Payout']?.last ?? 0;
    final divPayouts = data.payouts.where((p) => p.type == 'Dividend').toList();
    final divGrowth = _avgGrowth(divPayouts.map((p) => p.payoutPercent).toList());

    // Scores
    final divScore = (
      (divYield / 5 * 40).clamp(0, 40) +
      (divGrowth / 20 * 30).clamp(0, 30) +
      ((70 - payoutRatio) / 70 * 30).clamp(0, 30)
    ).clamp(0, 100.0);

    final roeLast = roe.isNotEmpty ? roe.last : 0;
    final nmLast  = nm.isNotEmpty  ? nm.last  : 0;
    final growthScore = (
      (revenueGrowth / 25 * 30).clamp(0, 30) +
      (profitGrowth  / 30 * 30).clamp(0, 30) +
      (roeLast       / 30 * 20).clamp(0, 20) +
      (nmLast        / 30 * 20).clamp(0, 20)
    ).clamp(0, 100.0);

    final diff = divScore - growthScore;
    final category = diff > 15  ? 'STRONG DIVIDEND STOCK'
                   : diff > 0   ? 'DIVIDEND-LEANING STOCK'
                   : diff > -15 ? 'GROWTH-LEANING STOCK'
                   :              'STRONG GROWTH STOCK';
    final isDividend = diff >= 0;
    final catColor = isDividend ? const Color(0xFFc49a00) : const Color(0xFF1a7a4a);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Classification card
          SectionCard(
            title: 'Stock Classification',
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: catColor),
                  ),
                  child: Text(category,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                        color: catColor)),
                ),
                const SizedBox(height: 14),
                // Score comparison bars
                _scoreBar('Dividend Score', divScore, const Color(0xFFc49a00)),
                const SizedBox(height: 8),
                _scoreBar('Growth Score', growthScore, const Color(0xFF1a7a4a)),
                const SizedBox(height: 14),
                _metricsGrid(
                  revenueGrowth, profitGrowth, epsGrowth,
                  divYield, divGrowth, payoutRatio, roeLast, nmLast,
                ),
              ],
            ),
          ),

          // Revenue, GP, PAT trend
          SectionCard(
            title: 'Revenue & Profitability Trend',
            subtitle: 'PKR Millions',
            child: SizedBox(
              height: 220,
              child: LineChart(LineChartData(
                lineBarsData: [
                  _line(sales.map((v) => v / 1e6).toList(), const Color(0xFF1a3a5c)),
                  _line(gp.map((v) => v / 1e6).toList(),    const Color(0xFF1a7a4a)),
                  _line(pat.map((v) => v / 1e6).toList(),   const Color(0xFFc49a00)),
                ],
                titlesData: _bottomTitles(years),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true),
              )),
            ),
          ),

          // EPS bar chart
          SectionCard(
            title: 'Earnings Per Share (EPS)',
            subtitle: 'PKR',
            child: SizedBox(
              height: 170,
              child: BarChart(BarChartData(
                barGroups: List.generate(eps.length, (i) => BarChartGroupData(
                  x: i,
                  barRods: [BarChartRodData(
                    toY: eps[i],
                    color: eps[i] >= 5 ? const Color(0xFF1a7a4a) : const Color(0xFFc49a00),
                    width: 18,
                    borderRadius: BorderRadius.circular(4),
                  )],
                )),
                titlesData: _bottomTitles(years),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBar(String label, double score, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text('${score.toStringAsFixed(1)}/100',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: score / 100,
          minHeight: 10,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ]);
  }

  Widget _metricsGrid(
    double revGrow, double profGrow, double epsGrow,
    double divYield, double divGrow, double payout,
    double roe, double nm,
  ) {
    final rows = [
      ('Revenue Growth (avg)', '${revGrow.toStringAsFixed(1)}%'),
      ('Profit Growth (avg)',  '${profGrow.toStringAsFixed(1)}%'),
      ('EPS Growth (avg)',     '${epsGrow.toStringAsFixed(1)}%'),
      ('Dividend Yield',       '${divYield.toStringAsFixed(2)}%'),
      ('Dividend Growth',      '${divGrow.toStringAsFixed(1)}%'),
      ('Payout Ratio',         '${payout.toStringAsFixed(1)}%'),
      ('Return on Equity',     '${roe.toStringAsFixed(1)}%'),
      ('Net Margin',           '${nm.toStringAsFixed(1)}%'),
    ];
    return Table(
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
      children: rows.map((r) => TableRow(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFe0e0e0))),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(r.$1, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(r.$2,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                textAlign: TextAlign.right),
          ),
        ],
      )).toList(),
    );
  }

  LineChartBarData _line(List<double> vals, Color color) => LineChartBarData(
    spots: List.generate(vals.length, (i) => FlSpot(i.toDouble(), vals[i])),
    isCurved: true, color: color, barWidth: 2.5,
    dotData: const FlDotData(show: false),
  );

  FlTitlesData _bottomTitles(List<String> years) => FlTitlesData(
    bottomTitles: AxisTitles(sideTitles: SideTitles(
      showTitles: true,
      getTitlesWidget: (v, _) {
        final i = v.toInt();
        return i < years.length
            ? Text(years[i], style: const TextStyle(fontSize: 9))
            : const Text('');
      },
    )),
    leftTitles: AxisTitles(sideTitles: SideTitles(
      showTitles: true, reservedSize: 40,
      getTitlesWidget: (v, _) =>
          Text(formatNumber(v, decimals: 0), style: const TextStyle(fontSize: 9)),
    )),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  );
}
