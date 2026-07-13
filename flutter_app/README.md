# PSX Financial Analysis — Flutter Android App

A **Flutter/Dart** Android application that provides a full financial analysis dashboard
for PSX (Pakistan Stock Exchange) stocks, powered by the bundled financial data.

## Features

| Screen | Description |
|--------|-------------|
| 📊 **Company Snapshot** | Key metrics (price, market cap, yield, ratios), 52-week range bar, financial composition pie chart, assets vs liabilities chart |
| 📉 **Income Statement** | Revenue / Gross Profit / Net Profit trend, Revenue vs COGS, EPS bar chart, EBITDA trend |
| 💸 **Dividend Analysis** | Quality score gauge, payout history, EPS trend, payout ratio trend |
| 💵 **Cash Flow** | Operating / Investing / Financing CF grouped bar, FCFF chart, cash position trend |
| 📐 **Financial Ratios** | Profitability, Returns, Liquidity, Leverage tabs with trend charts and data tables |
| 📈 **Growth Analysis** | Dividend vs Growth score bars, stock classification (Strong Dividend / Dividend-Leaning / Growth-Leaning / Strong Growth), revenue trend, EPS chart |

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.0.0
- Android Studio or VS Code with Flutter extension
- Android device or emulator (API 21+)

## Setup & Run

```bash
# 1. Navigate to the flutter_app directory
cd flutter_app

# 2. Install dependencies
flutter pub get

# 3. Run on a connected device / emulator
flutter run

# 4. Build a release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

## Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                    # App entry point + HomeScreen + LoadingScreen
│   ├── models/
│   │   └── financial_data.dart      # Data classes + CSV loader
│   ├── screens/
│   │   ├── snapshot_screen.dart     # Company Snapshot
│   │   ├── income_screen.dart       # Income Statement
│   │   ├── dividend_screen.dart     # Dividend Analysis
│   │   ├── cash_flow_screen.dart    # Cash Flow
│   │   ├── ratios_screen.dart       # Financial Ratios (tabbed)
│   │   └── growth_screen.dart       # Growth vs Dividend Analysis
│   ├── widgets/
│   │   ├── metric_card.dart         # Reusable metric tile
│   │   └── section_card.dart        # Reusable section wrapper
│   └── utils/
│       └── number_formatter.dart    # PKR/B/M/K formatter
├── assets/
│   └── financial_data/             # Pre-loaded CSV data files
│       ├── company_snapshot.csv
│       ├── income_statement.csv
│       ├── balance_sheet.csv
│       ├── cash_flow.csv
│       ├── financial_ratios.csv
│       └── payouts.csv
├── android/                        # Standard Android project files
└── pubspec.yaml                    # Flutter dependencies
```

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `fl_chart` | Interactive financial charts (line, bar, pie) |
| `csv` | Parse bundled CSV data files |
| `intl` | Number/currency formatting (PKR) |
| `url_launcher` | Open external links |

## Updating Data

Replace the CSV files in `assets/financial_data/` with freshly scraped data from the Streamlit app:

```bash
# From the repo root, download fresh data
streamlit run src/streamlit_app.py
# Use the "📥 Data Download" page, then copy the CSV files:
cp financial_data/*.csv flutter_app/assets/financial_data/
```
