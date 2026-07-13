/// Company Snapshot screen — key metrics, 52-week range, composition.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/financial_data.dart';
import '../utils/number_formatter.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_card.dart';

class SnapshotScreen extends StatelessWidget {
  final FinancialDataset data;
  const SnapshotScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final s = data.snapshot;
    final bs = data.balanceSheet;
    final inc = data.incomeStatement;

    final totalLiab = bs['Total Liabilities']?.last ?? 0;
    final equity    = bs['Shareholder Equity']?.last ?? 0;
    final revenue   = inc['Sales']?.last ?? 0;
    final netProfit = inc['PAT']?.last ?? 0;

    final rangeProgress = (s.high52w == s.low52w)
        ? 0.5
        : ((s.currentPrice - s.low52w) / (s.high52w - s.low52w)).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Metric grid ──
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.0,
            children: [
              MetricCard(
                label: 'Current Price',
                value: formatPkr(s.currentPrice),
                icon: Icons.monetization_on_outlined,
                accentColor: const Color(0xFF1a7a4a),
              ),
              MetricCard(
                label: 'Market Cap',
                value: formatNumber(s.marketCap),
                icon: Icons.bar_chart,
                accentColor: const Color(0xFF1a3a5c),
              ),
              MetricCard(
                label: 'Dividend Yield',
                value: '${s.dividendYield.toStringAsFixed(2)}%',
                icon: Icons.savings_outlined,
                accentColor: const Color(0xFFc49a00),
              ),
              MetricCard(
                label: 'Current Ratio',
                value: '${s.currentRatio.toStringAsFixed(2)}x',
                icon: Icons.speed_outlined,
                accentColor: Colors.blue[700]!,
              ),
              MetricCard(
                label: 'Book Value / Share',
                value: formatPkr(s.bookValue),
                icon: Icons.menu_book_outlined,
                accentColor: Colors.purple[600]!,
              ),
              MetricCard(
                label: 'Debt / Equity',
                value: s.debtToEquity.toStringAsFixed(2),
                icon: Icons.account_balance_outlined,
                accentColor: Colors.red[700]!,
              ),
              MetricCard(
                label: 'Beta',
                value: s.beta.toStringAsFixed(2),
                icon: Icons.show_chart,
                accentColor: Colors.green[700]!,
              ),
              MetricCard(
                label: 'Free Float',
                value: '${s.freeFloatPercent.toStringAsFixed(1)}%',
                icon: Icons.people_outline,
                accentColor: Colors.cyan[700]!,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── 52-Week Range ──
          SectionCard(
            title: '52-Week Price Range',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Low: PKR ${s.low52w.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: Colors.red)),
                    Text('PKR ${s.currentPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('High: PKR ${s.high52w.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: rangeProgress,
                    minHeight: 12,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF1a7a4a)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(rangeProgress * 100).toStringAsFixed(0)}% of 52-week range',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // ── Financial Composition Pie ──
          SectionCard(
            title: 'Financial Composition (${data.years.last})',
            child: SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                  sections: [
                    _pieSection(revenue,   'Revenue',    const Color(0xFF1a7a4a)),
                    _pieSection(netProfit, 'Net Profit', const Color(0xFF4caf50)),
                    _pieSection(totalLiab, 'Liabilities',const Color(0xFFdc3545)),
                    _pieSection(equity,    'Equity',     const Color(0xFF1a3a5c)),
                  ],
                ),
              ),
            ),
          ),

          // ── Assets vs Liabilities bar chart ──
          SectionCard(
            title: 'Assets vs Liabilities vs Equity',
            subtitle: 'PKR Millions',
            child: SizedBox(
              height: 220,
              child: _buildAssetLiabChart(data),
            ),
          ),
        ],
      ),
    );
  }

  PieChartSectionData _pieSection(double value, String label, Color color) {
    final v = value / 1e6;
    return PieChartSectionData(
      value: v.abs(),
      color: color,
      title: label,
      radius: 70,
      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  Widget _buildAssetLiabChart(FinancialDataset data) {
    final bs = data.balanceSheet;
    final years = data.years;
    final assets  = bs['Total Assets'] ?? [];
    final liabs   = bs['Total Liabilities'] ?? [];
    final equity  = bs['Shareholder Equity'] ?? [];

    return BarChart(
      BarChartData(
        barGroups: List.generate(years.length, (i) {
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: (assets[i])  / 1e6, color: const Color(0xFF1a3a5c), width: 8),
            BarChartRodData(toY: (liabs[i])   / 1e6, color: const Color(0xFFdc3545), width: 8),
            BarChartRodData(toY: (equity[i])  / 1e6, color: const Color(0xFF1a7a4a), width: 8),
          ]);
        }),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (v, _) => Text('${(v/1000).toStringAsFixed(0)}B',
                style: const TextStyle(fontSize: 9)),
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final idx = v.toInt();
              return idx < years.length
                  ? Text(years[idx], style: const TextStyle(fontSize: 9))
                  : const Text('');
            },
          )),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true),
      ),
    );
  }
}
