import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objs as go
import os

# Import analysis classes
from analyze_investments import DividendAnalyzer
from growth_or_dividend import StockCategorizer

# Import stock scrapper
from stock_scrapper import scrape_company_data

# ──────────────────────────────────────────────
# Utilities
# ──────────────────────────────────────────────

def format_number(value, decimals: int = 2) -> str:
    """Format large numbers as B / M / K for readability."""
    try:
        value = float(value)
    except (TypeError, ValueError):
        return "N/A"
    if abs(value) >= 1_000_000_000:
        return f"{value / 1_000_000_000:.{decimals}f} B"
    if abs(value) >= 1_000_000:
        return f"{value / 1_000_000:.{decimals}f} M"
    if abs(value) >= 1_000:
        return f"{value / 1_000:.{decimals}f} K"
    return f"{value:.{decimals}f}"


def pct_delta(series: pd.Series) -> float | None:
    """Return % change between last two non-NaN values."""
    vals = series.dropna()
    if len(vals) < 2:
        return None
    return float((vals.iloc[0] - vals.iloc[1]) / abs(vals.iloc[1]) * 100) if vals.iloc[1] != 0 else None


# ──────────────────────────────────────────────
# Data Loading
# ──────────────────────────────────────────────

@st.cache_data(ttl=300)
def load_financial_data(data_dir: str = "financial_data"):
    try:
        payouts          = pd.read_csv(os.path.join(data_dir, "payouts.csv"))
        ratios           = pd.read_csv(os.path.join(data_dir, "financial_ratios.csv"), index_col="Metric")
        income_statement = pd.read_csv(os.path.join(data_dir, "income_statement.csv"), index_col="Metric")
        balance_sheet    = pd.read_csv(os.path.join(data_dir, "balance_sheet.csv"), index_col="Metric")
        snapshot         = pd.read_csv(os.path.join(data_dir, "company_snapshot.csv")).iloc[0]
        cash_flow        = pd.read_csv(os.path.join(data_dir, "cash_flow.csv"), index_col="Metric")

        return {
            "payouts": payouts,
            "ratios": ratios,
            "income_statement": income_statement,
            "balance_sheet": balance_sheet,
            "snapshot": snapshot,
            "cash_flow": cash_flow,
        }
    except Exception as e:
        st.error(f"Error loading financial data: {e}")
        return None


# ──────────────────────────────────────────────
# Pages
# ──────────────────────────────────────────────

def company_snapshot_page(data):
    st.header("📊 Company Snapshot")

    snap = data["snapshot"]
    ratios = data["ratios"]
    latest_year = ratios.columns[0]

    # ── Key Metrics row ──
    current_price = snap.get("Current", 0)
    high_52w      = snap.get("52W_High", snap.get("High", 0))
    low_52w       = snap.get("52W_Low",  snap.get("Low", 0))
    div_yield     = snap.get("Dividend_Yield", 0)
    market_cap    = snap.get("Market_Cap", 0)

    # Derive EPS and P/E from ratios when not present in snapshot
    eps_val = snap.get("EPS", None)
    if not eps_val:
        if "Earning Per Share" in ratios.index:
            eps_val = float(ratios.loc["Earning Per Share", latest_year])

    pe_val = snap.get("PE_Ratio", None)
    if not pe_val and eps_val:
        pe_val = round(current_price / eps_val, 2) if eps_val else None

    book_val = snap.get("Book_Value", None)
    if not book_val and "Book Value per Share" in ratios.index:
        book_val = float(ratios.loc["Book Value per Share", latest_year])

    st.subheader("Key Financial Indicators")
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("💰 Current Price", f"PKR {current_price:,.2f}",
              delta=f"52W High: {high_52w:,.2f}" if high_52w else None)
    c2.metric("📈 Market Cap", format_number(market_cap))
    c3.metric("🎯 Dividend Yield", f"{div_yield:.2f}%" if div_yield else "N/A")
    c4.metric("📊 P/E Ratio", f"{pe_val:.1f}x" if pe_val else "N/A")

    c5, c6, c7, c8 = st.columns(4)
    c5.metric("💵 EPS", f"PKR {eps_val:.2f}" if eps_val else "N/A")
    c6.metric("📚 Book Value / Share", f"PKR {book_val:.2f}" if book_val else "N/A")
    c7.metric("🏦 Current Ratio", f"{snap.get('Current_Ratio', 0):.2f}x")
    c8.metric("⚖️ Debt / Equity", f"{snap.get('Debt_to_Equity', 0):.2f}x")

    # ── 52-Week Price Range ──
    st.subheader("52-Week Price Range")
    if high_52w and low_52w and current_price:
        progress = (current_price - low_52w) / (high_52w - low_52w) if high_52w != low_52w else 0.5
        col_lo, col_bar, col_hi = st.columns([1, 6, 1])
        col_lo.markdown(f"**Low**<br>PKR {low_52w:,.2f}", unsafe_allow_html=True)
        col_bar.progress(float(np.clip(progress, 0, 1)))
        col_hi.markdown(f"**High**<br>PKR {high_52w:,.2f}", unsafe_allow_html=True)
        st.caption(f"Current price PKR {current_price:,.2f} is at {progress*100:.0f}% of the 52-week range.")

    # ── Financial Composition Pie ──
    st.subheader("Financial Composition")
    try:
        bs = data["balance_sheet"]
        inc = data["income_statement"]
        total_debt = (
            float(bs.loc["Interest Bearing Long Term Liability"].iloc[0])
            + float(bs.loc["Interest Bearing Short Term Liability"].iloc[0])
            if "Interest Bearing Long Term Liability" in bs.index and
               "Interest Bearing Short Term Liability" in bs.index
            else 0
        )
        composition = {
            "Revenue":  float(inc.loc["Sales"].iloc[0]),
            "Net Profit": float(inc.loc["PAT"].iloc[0]),
            "Total Debt": total_debt,
            "Equity":   float(bs.loc["Shareholder Equity"].iloc[0])
                        if "Shareholder Equity" in bs.index else 0,
        }
        composition = {k: v for k, v in composition.items() if v > 0}
        fig = px.pie(values=list(composition.values()), names=list(composition.keys()),
                     title="Financial Composition", hole=0.35)
        st.plotly_chart(fig, use_container_width=True)
    except Exception as e:
        st.warning(f"Could not render composition chart: {e}")

    # ── Balance Sheet Assets vs Liabilities over time ──
    st.subheader("Assets vs Liabilities Trend")
    try:
        bs = data["balance_sheet"]
        years = bs.columns
        assets = bs.loc["Total Assets"] if "Total Assets" in bs.index else None
        liabilities_row = None
        for candidate in ["Total Liabilities", "Total Liability", "Liabilities"]:
            if candidate in bs.index:
                liabilities_row = bs.loc[candidate]
                break

        if assets is not None and liabilities_row is not None:
            fig2 = go.Figure()
            fig2.add_trace(go.Bar(x=years, y=assets.values, name="Total Assets"))
            fig2.add_trace(go.Bar(x=years, y=liabilities_row.values, name="Total Liabilities"))
            fig2.update_layout(barmode="group", title="Assets vs Liabilities",
                               xaxis_title="Year", yaxis_title="PKR")
            st.plotly_chart(fig2, use_container_width=True)
        elif assets is not None:
            fig2 = px.bar(x=years, y=assets.values, title="Total Assets Over Time",
                          labels={"x": "Year", "y": "PKR"})
            st.plotly_chart(fig2, use_container_width=True)
    except Exception as e:
        st.warning(f"Could not render balance sheet chart: {e}")


def dividend_analysis_page(data):
    st.header("💸 Dividend Quality Analysis")

    analyzer = DividendAnalyzer(data["payouts"], data["ratios"], data["income_statement"])
    report   = analyzer.generate_report()
    metrics  = analyzer.analyze_dividend_quality()

    # Score gauge
    score = metrics["total_score"]
    color = "green" if score >= 65 else "orange" if score >= 50 else "red"
    fig_gauge = go.Figure(go.Indicator(
        mode="gauge+number",
        value=score,
        title={"text": "Dividend Quality Score"},
        gauge={
            "axis": {"range": [0, 100]},
            "bar":  {"color": color},
            "steps": [
                {"range": [0, 50],  "color": "#ffe5e5"},
                {"range": [50, 65], "color": "#fff3cd"},
                {"range": [65, 100],"color": "#d4edda"},
            ],
        },
        domain={"x": [0, 1], "y": [0, 1]},
    ))
    fig_gauge.update_layout(height=250, margin=dict(t=30, b=10))
    st.plotly_chart(fig_gauge, use_container_width=True)

    st.markdown(report)

    # Yearly dividend payout trend
    st.subheader("Annual Dividend Payout History")
    yearly_payouts = metrics["yearly_payouts"]
    if len(yearly_payouts) > 0:
        fig = px.bar(
            x=yearly_payouts.index,
            y=yearly_payouts.values,
            title="Annual Dividend Payout (%)",
            labels={"x": "Year", "y": "Total Payout (%)"},
            color=yearly_payouts.values,
            color_continuous_scale="Blues",
        )
        fig.update_layout(coloraxis_showscale=False)
        st.plotly_chart(fig, use_container_width=True)

    # Payout vs EPS trend
    st.subheader("EPS vs Payout Ratio Trend")
    try:
        ratios = data["ratios"]
        years  = ratios.columns
        eps_series    = ratios.loc["Earning Per Share"] if "Earning Per Share" in ratios.index else None
        payout_series = ratios.loc["Payout"]           if "Payout" in ratios.index else None

        if eps_series is not None and payout_series is not None:
            fig2 = go.Figure()
            fig2.add_trace(go.Scatter(x=years, y=eps_series.values,
                                      name="EPS (PKR)", mode="lines+markers"))
            fig2.add_trace(go.Bar(x=years, y=payout_series.values,
                                  name="Payout Ratio (%)", opacity=0.5,
                                  yaxis="y2"))
            fig2.update_layout(
                title="EPS vs Payout Ratio",
                yaxis=dict(title="EPS (PKR)"),
                yaxis2=dict(title="Payout Ratio (%)", overlaying="y", side="right"),
                legend=dict(x=0, y=1.1, orientation="h"),
            )
            st.plotly_chart(fig2, use_container_width=True)
    except Exception as e:
        st.warning(f"Could not render EPS/Payout chart: {e}")


def growth_analysis_page(data):
    st.header("🚀 Stock Growth Analysis")

    categorizer = StockCategorizer(
        data["income_statement"],
        data["ratios"],
        data["payouts"],
        data["snapshot"],
    )
    report = categorizer.categorize_stock()
    st.markdown(report)

    # Revenue, Gross Profit, and PAT trend
    st.subheader("Revenue & Profitability Trend")
    inc   = data["income_statement"]
    years = inc.columns

    fig = go.Figure()
    for metric, label in [("Sales", "Revenue"), ("Gross Profit", "Gross Profit"), ("PAT", "Net Profit")]:
        if metric in inc.index:
            fig.add_trace(go.Scatter(x=years, y=inc.loc[metric].values,
                                     name=label, mode="lines+markers"))
    fig.update_layout(title="Revenue & Profitability", xaxis_title="Year",
                      yaxis_title="PKR", hovermode="x unified")
    st.plotly_chart(fig, use_container_width=True)

    # Revenue vs COGS bar chart
    st.subheader("Revenue vs Cost of Goods Sold")
    try:
        fig2 = go.Figure()
        fig2.add_trace(go.Bar(x=years, y=inc.loc["Sales"].values,  name="Revenue"))
        fig2.add_trace(go.Bar(x=years, y=inc.loc["COGS"].values,   name="COGS"))
        fig2.update_layout(barmode="group", title="Revenue vs COGS",
                           xaxis_title="Year", yaxis_title="PKR")
        st.plotly_chart(fig2, use_container_width=True)
    except Exception:
        pass

    # EPS trend
    st.subheader("Earnings Per Share (EPS) Trend")
    if "EPS" in inc.index:
        fig3 = px.line(x=years, y=inc.loc["EPS"].values,
                       title="EPS Over Time", labels={"x": "Year", "y": "PKR"},
                       markers=True)
        fig3.update_traces(line_color="#2196F3")
        st.plotly_chart(fig3, use_container_width=True)


def cash_flow_page(data):
    st.header("💵 Cash Flow Analysis")

    cf    = data["cash_flow"]
    years = cf.columns

    # Key cash flow metrics
    st.subheader("Cash Flow Overview")
    key_rows = {
        "Operating Cash Flow": "Operating CF",
        "Cashflow from Investing": "Investing CF",
        "Cash Flow from Financing": "Financing CF",
        "Net Change": "Net Change",
    }

    cols = st.columns(len(key_rows))
    for col, (row, label) in zip(cols, key_rows.items()):
        if row in cf.index:
            val   = float(cf.loc[row].iloc[0])
            delta = pct_delta(cf.loc[row])
            col.metric(label, format_number(val),
                       delta=f"{delta:.1f}%" if delta is not None else None,
                       delta_color="normal")

    # Waterfall / grouped bar of cash flows
    st.subheader("Cash Flow Components by Year")
    fig = go.Figure()
    colors = {"Operating Cash Flow": "#4CAF50",
              "Cashflow from Investing": "#2196F3",
              "Cash Flow from Financing": "#FF9800"}
    for row, color in colors.items():
        if row in cf.index:
            fig.add_trace(go.Bar(x=years, y=cf.loc[row].values,
                                 name=row, marker_color=color))
    fig.update_layout(barmode="group", title="Cash Flow Components",
                      xaxis_title="Year", yaxis_title="PKR",
                      hovermode="x unified")
    st.plotly_chart(fig, use_container_width=True)

    # Free Cash Flow (FCFF) trend
    if "FCFF" in cf.index:
        st.subheader("Free Cash Flow to Firm (FCFF)")
        fcff = cf.loc["FCFF"].values
        colors_fcff = ["#4CAF50" if v >= 0 else "#F44336" for v in fcff]
        fig2 = go.Figure(go.Bar(x=years, y=fcff, marker_color=colors_fcff,
                                name="FCFF"))
        fig2.add_hline(y=0, line_dash="dash", line_color="gray")
        fig2.update_layout(title="Free Cash Flow to Firm (FCFF)",
                           xaxis_title="Year", yaxis_title="PKR")
        st.plotly_chart(fig2, use_container_width=True)

    # Opening vs Closing Cash
    if "Opening Cash" in cf.index and "Closing Cash" in cf.index:
        st.subheader("Opening vs Closing Cash")
        fig3 = go.Figure()
        fig3.add_trace(go.Scatter(x=years, y=cf.loc["Opening Cash"].values,
                                  name="Opening Cash", mode="lines+markers"))
        fig3.add_trace(go.Scatter(x=years, y=cf.loc["Closing Cash"].values,
                                  name="Closing Cash", mode="lines+markers"))
        fig3.update_layout(title="Cash Position", xaxis_title="Year",
                           yaxis_title="PKR", hovermode="x unified")
        st.plotly_chart(fig3, use_container_width=True)


def financial_ratios_page(data):
    st.header("📐 Financial Ratios")

    ratios = data["ratios"]
    years  = ratios.columns

    ratio_groups = {
        "Profitability": ["Net Profit Margin", "Gross Profit Margin",
                          "Return on Equity", "Return on Assets",
                          "Return on Capital Employed"],
        "Liquidity":     ["Current Ratio", "Acid Test",
                          "Net Working Capital to Total Asseets"],
        "Leverage":      ["Debt To Equity", "Total Debt Ratio",
                          "Times Interest Earned"],
        "Efficiency":    ["Total Assets Turnover", "Average Collection Period",
                          "Days sales Inventory"],
        "Per Share":     ["Earning Per Share", "Book Value per Share",
                          "Payout", "Plow Back"],
    }

    selected_group = st.selectbox("Select Ratio Category", list(ratio_groups.keys()))
    metrics_in_group = [m for m in ratio_groups[selected_group] if m in ratios.index]

    if not metrics_in_group:
        st.info("No data available for this category.")
        return

    # Latest-year snapshot table
    st.subheader(f"{selected_group} Ratios — Latest Year ({years[0]})")
    snap_data = {m: ratios.loc[m, years[0]] for m in metrics_in_group}
    snap_df = pd.DataFrame.from_dict(snap_data, orient="index", columns=["Value"])
    st.dataframe(snap_df.style.format({"Value": "{:.2f}"}), use_container_width=True)

    # Trend chart
    st.subheader("Historical Trend")
    selected_metrics = st.multiselect(
        "Select metrics to plot",
        options=metrics_in_group,
        default=metrics_in_group[:min(3, len(metrics_in_group))],
    )

    if selected_metrics:
        fig = go.Figure()
        for m in selected_metrics:
            fig.add_trace(go.Scatter(x=years, y=ratios.loc[m].values,
                                     name=m, mode="lines+markers"))
        fig.update_layout(title=f"{selected_group} Ratios Over Time",
                          xaxis_title="Year", hovermode="x unified",
                          legend=dict(x=0, y=1.1, orientation="h"))
        st.plotly_chart(fig, use_container_width=True)


def data_download_page():
    st.header("📥 Stock Data Download")

    symbol = st.text_input("Enter PSX Stock Symbol (e.g., MARI, ENGRO)", value="MARI").upper()

    if st.button("⬇️ Download Financial Data", type="primary"):
        if not symbol:
            st.warning("Please enter a stock symbol.")
            return
        try:
            os.makedirs("financial_data", exist_ok=True)
            with st.spinner(f"Downloading data for **{symbol}** from Sarmaaya.pk …"):
                scrape_company_data(symbol)
            st.success(f"✅ Successfully downloaded data for **{symbol}**")
            load_financial_data.clear()   # invalidate cache

            st.subheader("Downloaded Files")
            files = sorted(os.listdir("financial_data"))
            for fname in files:
                fpath = os.path.join("financial_data", fname)
                try:
                    df = pd.read_csv(fpath)
                    with st.expander(fname):
                        st.dataframe(df, use_container_width=True)
                except Exception as e:
                    st.error(f"Could not preview {fname}: {e}")
        except Exception as e:
            st.error(f"Error downloading data: {e}")


# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────

def main():
    st.set_page_config(
        page_title="PSX Financial Dashboard",
        page_icon="📈",
        layout="wide",
        initial_sidebar_state="expanded",
    )

    st.title("📈 PSX Financial Analysis Dashboard")

    data = load_financial_data()

    # Sidebar
    with st.sidebar:
        st.header("Navigation")
        page = st.selectbox(
            "Select Page",
            [
                "📥 Data Download",
                "📊 Company Snapshot",
                "💸 Dividend Analysis",
                "🚀 Growth Analysis",
                "💵 Cash Flow",
                "📐 Financial Ratios",
            ],
        )

        if data is not None:
            snap = data["snapshot"]
            st.divider()
            st.subheader("Quick Stats")
            st.markdown(f"**Price:** PKR {snap.get('Current', 'N/A'):,.2f}"
                        if snap.get("Current") else "**Price:** N/A")
            div_yield = snap.get("Dividend_Yield", 0)
            st.markdown(f"**Div Yield:** {div_yield:.2f}%" if div_yield else "**Div Yield:** N/A")
            mkt_cap = snap.get("Market_Cap", 0)
            st.markdown(f"**Mkt Cap:** {format_number(mkt_cap)}" if mkt_cap else "**Mkt Cap:** N/A")

    if data is None:
        st.error("Could not load financial data. Please use **📥 Data Download** to fetch data first.")
        data_download_page()
        return

    page_map = {
        "📥 Data Download":    data_download_page,
        "📊 Company Snapshot": lambda: company_snapshot_page(data),
        "💸 Dividend Analysis":lambda: dividend_analysis_page(data),
        "🚀 Growth Analysis":  lambda: growth_analysis_page(data),
        "💵 Cash Flow":        lambda: cash_flow_page(data),
        "📐 Financial Ratios": lambda: financial_ratios_page(data),
    }

    page_map[page]()


if __name__ == "__main__":
    main()
