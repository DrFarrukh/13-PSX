/// Cash Flow Analysis screen.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/financial_data.dart';
import '../utils/number_formatter.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_card.dart';

class CashFlowScreen extends StatelessWidget {
  final FinancialDataset data;
  const CashFlowScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final cf    = data.cashFlow;
    final years = data.years;

    final operating = cf['Operating Cash Flow'] ?? [];
    final investing  = cf['Cashflow from Investing'] ?? [];
    final financing  = cf['Cash Flow from Financing'] ?? [];
    final fcff       = cf['FCFF'] ?? [];
    final opening    = cf['Opening Cash'] ?? [];
    final closing    = cf['Closing Cash'] ?? [];

    final lastOp = operating.isNotEmpty ? operating.last : 0;
    final lastCl = closing.isNotEmpty   ? closing.last   : 0;
    final lastFi = financing.isNotEmpty ? financing.last  : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Quick metrics
          Row(children: [
            Expanded(child: MetricCard(
              label: 'Operating CF (2023)',
              value: '${formatNumber(lastOp / 1e6)} M',
              accentColor: lastOp >= 0 ? Colors.green : Colors.red,
              icon: Icons.trending_up,
            )),
            const SizedBox(width: 10),
            Expanded(child: MetricCard(
              label: 'Closing Cash (2023)',
              value: '${formatNumber(lastCl / 1e6)} M',
              accentColor: const Color(0xFF1a7a4a),
              icon: Icons.account_balance_wallet_outlined,
            )),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: MetricCard(
              label: 'Financing CF (2023)',
              value: '${formatNumber(lastFi / 1e6)} M',
              accentColor: lastFi >= 0 ? Colors.blue : Colors.orange,
              icon: Icons.swap_horiz,
            )),
            const SizedBox(width: 10),
            Expanded(child: MetricCard(
              label: 'FCFF (2023)',
              value: fcff.isNotEmpty ? '${formatNumber(fcff.last / 1e6)} M' : 'N/A',
              accentColor: (fcff.isNotEmpty && fcff.last >= 0) ? Colors.green : Colors.red,
              icon: Icons.waterfall_chart,
            )),
          ]),
          const SizedBox(height: 16),

          // Cash flow components grouped bar
          SectionCard(
            title: 'Cash Flow Components by Year',
            subtitle: 'PKR Millions',
            child: SizedBox(
              height: 240,
              child: BarChart(BarChartData(
                barGroups: List.generate(years.length, (i) => BarChartGroupData(
                  x: i,
                  barRods: [
                    _rod(operating.isNotEmpty  ? operating[i]  / 1e6 : 0, const Color(0xFF1a7a4a)),
                    _rod(investing.isNotEmpty  ? investing[i]  / 1e6 : 0, const Color(0xFF0d6efd)),
                    _rod(financing.isNotEmpty  ? financing[i]  / 1e6 : 0, const Color(0xFFff9800)),
                  ],
                )),
                titlesData: _bottomTitles(years),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(y: 0, color: Colors.grey, strokeWidth: 1,
                      dashArray: [5, 5]),
                ]),
              )),
            ),
          ),

          // FCFF bar chart (green = positive, red = negative)
          if (fcff.isNotEmpty)
            SectionCard(
              title: 'Free Cash Flow to Firm (FCFF)',
              subtitle: 'PKR Millions',
              child: SizedBox(
                height: 200,
                child: BarChart(BarChartData(
                  barGroups: List.generate(years.length, (i) => BarChartGroupData(
                    x: i,
                    barRods: [BarChartRodData(
                      toY: fcff[i] / 1e6,
                      color: fcff[i] >= 0 ? const Color(0xFF1a7a4a) : Colors.red,
                      width: 18,
                      borderRadius: BorderRadius.circular(4),
                    )],
                  )),
                  titlesData: _bottomTitles(years),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true),
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    HorizontalLine(y: 0, color: Colors.grey, strokeWidth: 1,
                        dashArray: [5, 5]),
                  ]),
                )),
              ),
            ),

          // Opening vs Closing Cash
          if (opening.isNotEmpty && closing.isNotEmpty)
            SectionCard(
              title: 'Opening vs Closing Cash',
              subtitle: 'PKR Millions',
              child: SizedBox(
                height: 180,
                child: LineChart(LineChartData(
                  lineBarsData: [
                    _line(years, opening.map((v) => v / 1e6).toList(),
                        Colors.purple, 'Opening'),
                    _line(years, closing.map((v) => v / 1e6).toList(),
                        const Color(0xFF1a7a4a), 'Closing'),
                  ],
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

  BarChartRodData _rod(double y, Color color) => BarChartRodData(
    toY: y, color: color, width: 8, borderRadius: BorderRadius.circular(3),
  );

  LineChartBarData _line(List<String> years, List<double> vals, Color color, String _) =>
      LineChartBarData(
        spots: List.generate(vals.length, (i) => FlSpot(i.toDouble(), vals[i])),
        isCurved: true,
        color: color,
        barWidth: 2.5,
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
      getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0),
          style: const TextStyle(fontSize: 9)),
    )),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  );
}
