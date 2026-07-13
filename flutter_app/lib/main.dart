/// PSX Financial Analysis — Flutter Android App
/// Entry point.
library;

import 'package:flutter/material.dart';
import 'models/financial_data.dart';
import 'screens/snapshot_screen.dart';
import 'screens/income_screen.dart';
import 'screens/dividend_screen.dart';
import 'screens/cash_flow_screen.dart';
import 'screens/ratios_screen.dart';
import 'screens/growth_screen.dart';

void main() => runApp(const PsxApp());

class PsxApp extends StatelessWidget {
  const PsxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PSX Financial Analysis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1a7a4a),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1a3a5c),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: const _LoadingScreen(),
    );
  }
}

// ─────────────────── Loading Screen ───────────────────

class _LoadingScreen extends StatefulWidget {
  const _LoadingScreen();

  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await FinancialDataLoader.load();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(data: data)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1a3a5c),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📈', style: TextStyle(fontSize: 60)),
            SizedBox(height: 16),
            Text(
              'PSX Financial Analysis',
              style: TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Loading financial data…',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Color(0xFF4caf50)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────── Home Screen ───────────────────

class HomeScreen extends StatefulWidget {
  final FinancialDataset data;
  const HomeScreen({super.key, required this.data});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _navItems = [
    NavigationDestination(icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard), label: 'Snapshot'),
    NavigationDestination(icon: Icon(Icons.show_chart_outlined),
        selectedIcon: Icon(Icons.show_chart), label: 'Income'),
    NavigationDestination(icon: Icon(Icons.savings_outlined),
        selectedIcon: Icon(Icons.savings), label: 'Dividend'),
    NavigationDestination(icon: Icon(Icons.waterfall_chart_outlined),
        selectedIcon: Icon(Icons.waterfall_chart), label: 'Cash Flow'),
    NavigationDestination(icon: Icon(Icons.analytics_outlined),
        selectedIcon: Icon(Icons.analytics), label: 'Ratios'),
    NavigationDestination(icon: Icon(Icons.trending_up_outlined),
        selectedIcon: Icon(Icons.trending_up), label: 'Growth'),
  ];

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Company Snapshot',
      'Income Statement',
      'Dividend Analysis',
      'Cash Flow',
      'Financial Ratios',
      'Growth Analysis',
    ];

    final screens = [
      SnapshotScreen(data: widget.data),
      IncomeScreen(data: widget.data),
      DividendScreen(data: widget.data),
      CashFlowScreen(data: widget.data),
      RatiosScreen(data: widget.data),
      GrowthScreen(data: widget.data),
    ];

    final snap = widget.data.snapshot;

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'PKR ${snap.currentPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF4caf50), fontWeight: FontWeight.bold, fontSize: 13,
                  ),
                ),
                Text(
                  'Yield: ${snap.dividendYield.toStringAsFixed(2)}%',
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: _navItems,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        backgroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }
}
