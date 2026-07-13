/// Financial Ratios screen — profitability, liquidity, leverage trends.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/financial_data.dart';
import '../widgets/section_card.dart';

class RatiosScreen extends StatefulWidget {
  final FinancialDataset data;
  const RatiosScreen({super.key, required this.data});

  @override
  State<RatiosScreen> createState() => _RatiosScreenState();
}

class _RatiosScreenState extends State<RatiosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF1a7a4a),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1a7a4a),
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Profitability'),
            Tab(text: 'Returns'),
            Tab(text: 'Liquidity'),
            Tab(text: 'Leverage'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _ProfitabilityTab(data: widget.data),
              _ReturnsTab(data: widget.data),
              _LiquidityTab(data: widget.data),
              _LeverageTab(data: widget.data),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Profitability ───
class _ProfitabilityTab extends StatelessWidget {
  final FinancialDataset data;
  const _ProfitabilityTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final rat   = data.ratios;
    final years = data.years;
    final gm    = rat['Gross Profit Margin'] ?? [];
    final nm    = rat['Net Profit Margin']   ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SectionCard(
            title: 'Gross & Net Profit Margin (%)',
            child: SizedBox(
              height: 220,
              child: _lineChart(years, [
                (gm, const Color(0xFF1a7a4a), 'Gross Margin'),
                (nm, const Color(0xFFc49a00), 'Net Margin'),
              ]),
            ),
          ),
          _ratioTable(data, ['Gross Profit Margin', 'Net Profit Margin']),
        ],
      ),
    );
  }
}

// ─── Returns ───
class _ReturnsTab extends StatelessWidget {
  final FinancialDataset data;
  const _ReturnsTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final rat   = data.ratios;
    final years = data.years;
    final roe   = rat['Return on Equity']  ?? [];
    final roa   = rat['Return on Assets']  ?? [];
    final roce  = (rat['Return on Capital Employed'] ?? [])
        .map((v) => v * 100).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SectionCard(
            title: 'Return Metrics (%)',
            child: SizedBox(
              height: 220,
              child: _lineChart(years, [
                (roe,  const Color(0xFF1a3a5c), 'ROE'),
                (roa,  const Color(0xFF0d6efd), 'ROA'),
                (roce, Colors.purple,            'ROCE'),
              ]),
            ),
          ),
          _ratioTable(data, ['Return on Equity', 'Return on Assets']),
        ],
      ),
    );
  }
}

// ─── Liquidity ───
class _LiquidityTab extends StatelessWidget {
  final FinancialDataset data;
  const _LiquidityTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final rat   = data.ratios;
    final years = data.years;
    final cr    = rat['Current Ratio'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SectionCard(
            title: 'Current Ratio',
            child: SizedBox(
              height: 200,
              child: _lineChart(years, [(cr, const Color(0xFF198754), 'Current Ratio')]),
            ),
          ),
          _ratioTable(data, ['Current Ratio', 'Acid Test']),
        ],
      ),
    );
  }
}

// ─── Leverage ───
class _LeverageTab extends StatelessWidget {
  final FinancialDataset data;
  const _LeverageTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final rat   = data.ratios;
    final years = data.years;
    final de    = rat['Debt To Equity']  ?? [];
    final dr    = rat['Total Debt Ratio'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SectionCard(
            title: 'Debt / Equity & Total Debt Ratio',
            child: SizedBox(
              height: 200,
              child: _lineChart(years, [
                (de, Colors.red,    'D/E Ratio'),
                (dr, Colors.orange, 'Total Debt Ratio'),
              ]),
            ),
          ),
          _ratioTable(data, ['Debt To Equity', 'Total Debt Ratio', 'Times Interest Earned']),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───

Widget _ratioTable(FinancialDataset data, List<String> metrics) {
  final rat   = data.ratios;
  final years = data.years.reversed.take(5).toList();
  final yearCols = years;

  return SectionCard(
    title: 'Historical Values',
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
            color: Color(0xFF1a3a5c)),
        dataTextStyle: const TextStyle(fontSize: 11),
        columns: [
          const DataColumn(label: Text('Metric')),
          ...yearCols.map((y) => DataColumn(label: Text(y))),
        ],
        rows: metrics.map((m) {
          final vals = rat[m] ?? [];
          final reversedVals = vals.reversed.take(5).toList();
          return DataRow(cells: [
            DataCell(Text(m, style: const TextStyle(fontWeight: FontWeight.w600))),
            ...List.generate(yearCols.length, (i) {
              final v = i < reversedVals.length ? reversedVals[i] : null;
              return DataCell(Text(v != null ? v.toStringAsFixed(2) : '-'));
            }),
          ]);
        }).toList(),
      ),
    ),
  );
}

LineChartData _lineChart(
  List<String> years,
  List<(List<double>, Color, String)> series,
) {
  return LineChartData(
    lineBarsData: series.map((s) {
      final (vals, color, _) = s;
      return LineChartBarData(
        spots: List.generate(vals.length, (i) => FlSpot(i.toDouble(), vals[i])),
        isCurved: true,
        color: color,
        barWidth: 2.5,
        dotData: const FlDotData(show: false),
      );
    }).toList(),
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
        showTitles: true, reservedSize: 34,
        getTitlesWidget: (v, _) =>
            Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 9)),
      )),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    ),
    borderData: FlBorderData(show: false),
    gridData: const FlGridData(show: true),
  );
}
