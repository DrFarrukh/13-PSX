import pandas as pd
import numpy as np

class DividendAnalyzer:
    def __init__(self, payouts: pd.DataFrame, ratios: pd.DataFrame, income_statement: pd.DataFrame):
        self.payouts = payouts
        self.ratios = ratios
        self.income_statement = income_statement
        # Use the most recent year available in the ratios data
        self.latest_year = self.ratios.columns[0]

    def analyze_dividend_quality(self):
        div_data = self.payouts[self.payouts['Payout Type'] == 'Dividend']
        
        # Analyze consistency
        yearly_payouts = div_data.groupby(div_data['Year'].str[:4])['Payout %'].sum()
        consistency_score = min(len(yearly_payouts[yearly_payouts > 0]) / max(len(yearly_payouts), 1) * 40, 40)
        
        # Analyze growth trend
        recent_growth = yearly_payouts.pct_change().tail(5).mean() * 100
        if pd.isna(recent_growth):
            recent_growth = 0.0
        growth_score = min(recent_growth / 15 * 30, 30)
        
        # Analyze yield and sustainability
        current_yield = yearly_payouts.iloc[-1] if len(yearly_payouts) > 0 else 0.0
        payout_ratio = float(self.ratios.loc['Payout', self.latest_year])
        sustainability_score = max(0, (70 - payout_ratio) / 70 * 30)
        
        # Analyze earnings coverage
        eps_row = self.income_statement.loc['EPS'] if 'EPS' in self.income_statement.index else None
        eps_growth = float(eps_row.pct_change().mean() * 100) if eps_row is not None else 0.0
        if pd.isna(eps_growth):
            eps_growth = 0.0
        
        total_score = max(0, min(100, consistency_score + max(0, growth_score) + sustainability_score))
        
        return {
            'total_score': total_score,
            'consistency_years': len(yearly_payouts[yearly_payouts > 0]),
            'total_years': len(yearly_payouts),
            'avg_payout': float(yearly_payouts.mean()) if len(yearly_payouts) > 0 else 0.0,
            'growth_rate': recent_growth,
            'current_yield': current_yield,
            'payout_ratio': payout_ratio,
            'eps_growth': eps_growth,
            'yearly_payouts': yearly_payouts
        }

    def generate_report(self):
        metrics = self.analyze_dividend_quality()
        
        recommendation = "STRONG BUY" if metrics['total_score'] >= 80 else \
                        "BUY" if metrics['total_score'] >= 65 else \
                        "HOLD" if metrics['total_score'] >= 50 else "AVOID"

        return f"""## Dividend Quality Analysis

**Overall Score:** {metrics['total_score']:.1f} / 100  
**Recommendation:** `{recommendation}`

### Key Metrics
| Metric | Value |
|--------|-------|
| Dividend Consistency | {metrics['consistency_years']} of {metrics['total_years']} years |
| Average Annual Payout | {metrics['avg_payout']:.1f}% |
| 5-Year Growth Rate | {metrics['growth_rate']:.1f}% |
| Payout Ratio ({self.latest_year}) | {metrics['payout_ratio']:.1f}% |
| EPS Growth (avg) | {metrics['eps_growth']:.1f}% |

### Assessment
- **Dividend Sustainability:** {'🟢 High' if metrics['payout_ratio'] < 50 else '🟡 Moderate' if metrics['payout_ratio'] < 70 else '🔴 At Risk'}
- **Growth Trajectory:** {'🟢 Strong' if metrics['growth_rate'] > 10 else '🟡 Moderate' if metrics['growth_rate'] > 5 else '🔴 Weak'}
- **Income Reliability:** {'🟢 Excellent' if metrics['consistency_years'] > 10 else '🟡 Good' if metrics['consistency_years'] > 5 else '🔴 Limited'}
"""
