import pandas as pd
import numpy as np

class StockCategorizer:
    def __init__(self, income_statement, ratios, payouts, snapshot):
        self.income_statement = income_statement
        self.ratios = ratios
        self.payouts = payouts
        self.snapshot = snapshot
        # Use the most recent year available in the ratios data
        self.latest_year = self.ratios.columns[0]

    def analyze_dividend_strength(self):
        """Analyze dividend characteristics"""
        dividend_yield = float(self.snapshot.get('Dividend_Yield', 0) or 0)
        payout_ratio = float(self.ratios.loc['Payout', self.latest_year])
        
        # Calculate dividend growth from yearly payouts
        div_data = self.payouts[self.payouts['Payout Type'] == 'Dividend']
        yearly_payouts = div_data.groupby(div_data['Year'].str[:4])['Payout %'].sum()
        dividend_growth = float(yearly_payouts.pct_change().tail(5).mean() * 100) if len(yearly_payouts) > 1 else 0.0
        if pd.isna(dividend_growth):
            dividend_growth = 0.0
        
        dividend_score = max(0, min(100,
            min(dividend_yield / 5 * 40, 40) +   # Up to 40 points for yield
            min(max(0, dividend_growth) / 20 * 30, 30) +  # Up to 30 points for growth
            max(0, (70 - payout_ratio) / 70 * 30)         # Up to 30 points for sustainable payout
        ))
        
        return {
            'score': dividend_score,
            'yield': dividend_yield,
            'growth': dividend_growth,
            'payout_ratio': payout_ratio
        }

    def analyze_growth_strength(self):
        """Analyze growth characteristics"""
        # Calculate multi-year growth rates
        revenue_growth = float(self.income_statement.loc['Sales'].pct_change().mean() * 100)
        profit_growth = float(self.income_statement.loc['PAT'].pct_change().mean() * 100)
        eps_growth = float(self.income_statement.loc['EPS'].pct_change().mean() * 100) \
            if 'EPS' in self.income_statement.index else 0.0
        
        if pd.isna(revenue_growth):
            revenue_growth = 0.0
        if pd.isna(profit_growth):
            profit_growth = 0.0
        if pd.isna(eps_growth):
            eps_growth = 0.0
        
        # Get profitability metrics from the latest available year
        net_margin = float(self.ratios.loc['Net Profit Margin', self.latest_year])
        roe = float(self.ratios.loc['Return on Equity', self.latest_year])
        
        growth_score = max(0, min(100,
            min(revenue_growth / 25 * 30, 30) +   # Up to 30 points for revenue growth
            min(profit_growth / 30 * 30, 30) +    # Up to 30 points for profit growth
            min(roe / 30 * 20, 20) +              # Up to 20 points for ROE
            min(net_margin / 30 * 20, 20)         # Up to 20 points for margin
        ))
        
        return {
            'score': growth_score,
            'revenue_growth': revenue_growth,
            'profit_growth': profit_growth,
            'eps_growth': eps_growth,
            'net_margin': net_margin,
            'roe': roe
        }

    def categorize_stock(self):
        """Determine if stock is primarily dividend or growth focused"""
        dividend_metrics = self.analyze_dividend_strength()
        growth_metrics = self.analyze_growth_strength()
        
        score_diff = dividend_metrics['score'] - growth_metrics['score']
        if score_diff > 15:
            category = "STRONG DIVIDEND STOCK"
        elif score_diff > 0:
            category = "DIVIDEND-LEANING STOCK"
        elif score_diff > -15:
            category = "GROWTH-LEANING STOCK"
        else:
            category = "STRONG GROWTH STOCK"
        
        report = f"""## Stock Category Analysis

**Classification:** `{category}`  
*(Dividend Score: {dividend_metrics['score']:.1f} | Growth Score: {growth_metrics['score']:.1f})*

### Dividend Metrics (Score: {dividend_metrics['score']:.1f}/100)
| Metric | Value |
|--------|-------|
| Dividend Yield | {dividend_metrics['yield']:.2f}% |
| Dividend Growth Rate | {dividend_metrics['growth']:.1f}% |
| Payout Ratio ({self.latest_year}) | {dividend_metrics['payout_ratio']:.1f}% |

### Growth Metrics (Score: {growth_metrics['score']:.1f}/100)
| Metric | Value |
|--------|-------|
| Revenue Growth (avg) | {growth_metrics['revenue_growth']:.1f}% |
| Profit Growth (avg) | {growth_metrics['profit_growth']:.1f}% |
| EPS Growth (avg) | {growth_metrics['eps_growth']:.1f}% |
| Net Margin ({self.latest_year}) | {growth_metrics['net_margin']:.1f}% |
| Return on Equity ({self.latest_year}) | {growth_metrics['roe']:.1f}% |

**Primary Strength:** {"Dividend payments and stability" if "DIVIDEND" in category else "Business growth and profitability"}
"""
        return report
