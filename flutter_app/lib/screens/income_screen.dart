/// Income Statement screen — revenue/profit trends, EPS, EBITDA.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/financial_data.dart';
import '../utils/number_formatter.dart';
import '../widgets/section_card.dart';

class IncomeScreen extends StatelessWidget {
  final FinancialDataset data;
  const IncomeScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final inc   = data.incomeStatement;
    final years = data.years;
    final sales = inc['Sales'] ?? [];
    final cogs  = inc['COGS'] ?? [];
    final gp    = inc['Gross Profit'] ?? [];
    final pat   = inc['PAT'] ?? [];
    final eps   = inc['EPS'] ?? [];
    final ebitda = inc['EBITDA'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Revenue / Gross Profit / Net Profit trend
          SectionCard(
            title: 'Revenue, Gross Profit & Net Profit',
            subtitle: 'PKR Millions',
            child: SizedBox(
              height: 230,
              child: LineChart(_lineData(years, [
                (sales, const Color(0xFF1a3a5c), 'Revenue'),
                (gp,    const Color(0xFF1a7a4a), 'Gross Profit'),
                (pat,   const Color(0xFFc49a00), 'Net Profit'),
              ])),
            ),
          ),

          // Revenue vs COGS
          SectionCard(
            title: 'Revenue vs COGS',
            subtitle: 'PKR Millions',
            child: SizedBox(
              height: 200,
              child: BarChart(_groupedBarData(years, [
                (sales, const Color(0xFF1a3a5c)),
                (cogs,  const Color(0xFFe74c3c)),
              ])),
            ),
          ),

          // EPS
          SectionCard(
            title: 'Earnings Per Share (EPS)',
            subtitle: 'PKR',
            child: SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  barGroups: List.generate(years.length, (i) => BarChartGroupData(
                    x: i,
                    barRods: [BarChartRodData(
                      toY: eps.isNotEmpty ? eps[i] : 0,
                      color: (eps.isNotEmpty && eps[i] >= 5)
                          ? const Color(0xFF1a7a4a)
                          : const Color(0xFFc49a00),
                      width: 18,
                      borderRadius: BorderRadius.circular(4),
                    )],
                  )),
                  titlesData: _bottomTitles(years),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true),
                ),
              ),
            ),
          ),

          // EBITDA trend
          SectionCard(
            title: 'EBITDA Trend',
            subtitle: 'PKR Millions',
            child: SizedBox(
              height: 180,
              child: LineChart(_lineData(years, [
                (ebitda, Colors.purple, 'EBITDA'),
              ])),
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _lineData(
    List<String> years,
    List<(List<double>, Color, String)> series,
  ) {
    return LineChartData(
      lineBarsData: series.map((s) {
        final (vals, color, _) = s;
        return LineChartBarData(
          spots: List.generate(vals.length,
              (i) => FlSpot(i.toDouble(), vals[i] / 1e6)),
          isCurved: true,
          color: color,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
        );
      }).toList(),
      titlesData: _bottomTitles(years),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: true),
    );
  }

  BarChartData _groupedBarData(
    List<String> years,
    List<(List<double>, Color)> series,
  ) {
    return BarChartData(
      barGroups: List.generate(years.length, (i) => BarChartGroupData(
        x: i,
        barRods: series.map((s) {
          final (vals, color) = s;
          return BarChartRodData(
            toY: vals.isNotEmpty ? vals[i] / 1e6 : 0,
            color: color,
            width: 10,
            borderRadius: BorderRadius.circular(4),
          );
        }).toList(),
      )),
      titlesData: _bottomTitles(years),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: true),
    );
  }

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
      showTitles: true, reservedSize: 38,
      getTitlesWidget: (v, _) =>
          Text(formatNumber(v, decimals: 0), style: const TextStyle(fontSize: 9)),
    )),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  );
}
