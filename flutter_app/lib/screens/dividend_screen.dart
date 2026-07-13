/// Dividend Analysis screen — quality score, payout history, EPS vs Payout.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/financial_data.dart';
import '../widgets/section_card.dart';

class DividendScreen extends StatelessWidget {
  final FinancialDataset data;
  const DividendScreen({super.key, required this.data});

  double _calcScore() {
    final divPayouts = data.payouts.where((p) => p.type == 'Dividend').toList();
    final uniqueYears = divPayouts.map((p) => p.year).toSet();
    final consistency = (uniqueYears.length / 10).clamp(0.0, 1.0) * 40;

    final vals = divPayouts.map((p) => p.payoutPercent).toList();
    double growth = 0;
    if (vals.length > 1) {
      double sum = 0; int cnt = 0;
      for (int i = 1; i < vals.length && i < 6; i++) {
        if (vals[i - 1] > 0) { sum += (vals[i] - vals[i-1]) / vals[i-1] * 100; cnt++; }
      }
      growth = cnt > 0 ? (sum / cnt / 15 * 30).clamp(0.0, 30.0) : 0;
    }

    final payout = data.ratios['Payout']?.last ?? 0;
    final sustainability = ((70 - payout) / 70 * 30).clamp(0.0, 30.0);

    return (consistency + growth + sustainability).clamp(0.0, 100.0);
  }

  @override
  Widget build(BuildContext context) {
    final score = _calcScore();
    final rec   = score >= 80 ? 'STRONG BUY' : score >= 65 ? 'BUY'
                : score >= 50 ? 'HOLD' : 'AVOID';
    final recColor = score >= 65 ? Colors.green : score >= 50 ? Colors.orange : Colors.red;

    final divPayouts = data.payouts.where((p) => p.type == 'Dividend').toList();
    final years = data.years;
    final eps    = data.incomeStatement['EPS'] ?? [];
    final payout = data.ratios['Payout'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Score + recommendation
          SectionCard(
            title: 'Dividend Quality Score',
            child: Column(
              children: [
                // Score gauge (progress indicator)
                Stack(alignment: Alignment.center, children: [
                  SizedBox(
                    height: 120, width: 120,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 14,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(
                          score >= 65 ? Colors.green : score >= 50 ? Colors.orange : Colors.red),
                    ),
                  ),
                  Column(children: [
                    Text(score.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const Text('/100', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  decoration: BoxDecoration(
                    color: recColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: recColor),
                  ),
                  child: Text(rec, style: TextStyle(
                      color: recColor, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(height: 12),
                // Key metrics summary
                _summaryTable(divPayouts),
              ],
            ),
          ),

          // Payout history
          SectionCard(
            title: 'Annual Dividend Payout History (%)',
            child: SizedBox(
              height: 200,
              child: BarChart(BarChartData(
                barGroups: List.generate(divPayouts.length, (i) => BarChartGroupData(
                  x: i,
                  barRods: [BarChartRodData(
                    toY: divPayouts[i].payoutPercent,
                    color: divPayouts[i].payoutPercent >= 20
                        ? const Color(0xFF1a7a4a) : const Color(0xFFc49a00),
                    width: 22,
                    borderRadius: BorderRadius.circular(4),
                  )],
                )),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      return i < divPayouts.length
                          ? Transform.rotate(
                              angle: -0.5,
                              child: Text(divPayouts[i].year, style: const TextStyle(fontSize: 9)))
                          : const Text('');
                    },
                  )),
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 32,
                    getTitlesWidget: (v, _) =>
                        Text('${v.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 9)),
                  )),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true),
              )),
            ),
          ),

          // EPS trend
          SectionCard(
            title: 'EPS Trend',
            subtitle: 'PKR',
            child: SizedBox(
              height: 160,
              child: LineChart(LineChartData(
                lineBarsData: [LineChartBarData(
                  spots: List.generate(eps.length,
                      (i) => FlSpot(i.toDouble(), eps[i])),
                  isCurved: true,
                  color: const Color(0xFF1a3a5c),
                  barWidth: 2.5,
                  dotData: const FlDotData(show: true),
                )],
                titlesData: FlTitlesData(
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
                    showTitles: true, reservedSize: 32,
                    getTitlesWidget: (v, _) =>
                        Text(v.toStringAsFixed(0), style: const TextStyle(fontSize: 9)),
                  )),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true),
              )),
            ),
          ),

          // Payout ratio trend
          if (payout.isNotEmpty)
            SectionCard(
              title: 'Payout Ratio Trend (%)',
              child: SizedBox(
                height: 150,
                child: LineChart(LineChartData(
                  lineBarsData: [LineChartBarData(
                    spots: List.generate(payout.length,
                        (i) => FlSpot(i.toDouble(), payout[i])),
                    isCurved: false,
                    color: const Color(0xFFc49a00),
                    barWidth: 2,
                    dotData: const FlDotData(show: true),
                  )],
                  titlesData: FlTitlesData(
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
                      showTitles: true, reservedSize: 32,
                      getTitlesWidget: (v, _) =>
                          Text('${v.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 9)),
                    )),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true),
                )),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryTable(List<PayoutRecord> divPayouts) {
    final rows = [
      ('Dividend Payments', '${divPayouts.map((p) => p.year).toSet().length} years'),
      ('Latest Payout', divPayouts.isNotEmpty ? '${divPayouts.first.payoutPercent}%' : 'N/A'),
      ('Payout Ratio (2023)', '${data.ratios['Payout']?.last.toStringAsFixed(1) ?? 'N/A'}%'),
    ];
    return Table(
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
      children: rows.map((r) => TableRow(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(r.$1, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(r.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ])).toList(),
    );
  }
}
