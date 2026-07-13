import pandas as pd
from bs4 import BeautifulSoup
import requests
import os
import logging
import traceback
import time

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('scraper.log'),
        logging.StreamHandler()
    ]
)

_SESSION = requests.Session()
_HEADERS = {
    'User-Agent': (
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Safari/537.36'
    )
}
_MAX_RETRIES = 3
_RETRY_BACKOFF = 2  # seconds


def _get_with_retry(url: str, retries: int = _MAX_RETRIES) -> requests.Response:
    """GET request with exponential-backoff retry on transient errors."""
    for attempt in range(1, retries + 1):
        try:
            response = _SESSION.get(url, headers=_HEADERS, timeout=15)
            response.raise_for_status()
            return response
        except requests.RequestException as exc:
            if attempt == retries:
                logging.error(f"All {retries} attempts failed for {url}: {exc}")
                raise
            wait = _RETRY_BACKOFF ** attempt
            logging.warning(f"Attempt {attempt} failed for {url}: {exc}. Retrying in {wait}s…")
            time.sleep(wait)


def clean_value(value):
    """Convert string values like '1.26 K' or '147.00 B' to float with improved validation"""
    if value is None:
        return 0
        
    if isinstance(value, (int, float)):
        return float(value)
        
    if isinstance(value, str):
        value = value.strip()
        if value in ['-', '', 'N/A', 'None', 'null']:
            return 0
            
        # Remove commas and percentage signs; handle parentheses as negatives
        value = value.replace(',', '').replace('%', '')
        
        try:
            # Handle negative values in parentheses before stripping them
            if value.startswith('(') and value.endswith(')'):
                return -float(value[1:-1])
            # Remove remaining parentheses
            value = value.replace('(', '').replace(')', '')
            # Handle K (thousands)
            if 'K' in value:
                return float(value.replace('K', '')) * 1_000
            # Handle M (millions)
            elif 'M' in value:
                return float(value.replace('M', '')) * 1_000_000
            # Handle B (billions)
            elif 'B' in value:
                return float(value.replace('B', '')) * 1_000_000_000
            return float(value)
        except (ValueError, TypeError):
            logging.warning(f"Could not convert value '{value}' to float, returning 0")
            return 0
    return 0

def scrape_company_snapshot(soup):
    """Scrape company snapshot data from the soup object"""
    logging.info("Starting to scrape company snapshot")
    try:
        snapshot_data = {}
        snapshot_table = soup.find('div', {'class': 'company_snapshot_content'})
        
        if not snapshot_table:
            logging.warning("Company snapshot table not found")
            return {}
        
        # Map of titles to keys
        fields = {
            'Current Price': 'Current',
            'Volume': 'Volume',
            'Dividend': 'Dividend',
            'Dividend Yield': 'Dividend_Yield',
            'Price to Earnings Ratio': 'PE_Ratio',
            'Earnings Per Share': 'EPS',
            'EPS': 'EPS',
            'Book Value': 'Book_Value',
            'Price to Book': 'PB_Ratio',
            'Market Cap': 'Market_Cap',
            'Debt to Equity': 'Debt_to_Equity',
            'Net Profit Margin': 'Net_Profit_Margin',
            'Gross Profit Margin': 'Gross_Profit_Margin',
            'Current Ratio': 'Current_Ratio',
            'Shares': 'Shares',
            'FreeFloat': 'Free_Float',
            'Free Float %': 'Free_Float_Percent',
            'Equity to Asset': 'Equity_to_Asset',
            'Interest': 'Interest_Cover',
            'Beta': 'Beta',
            'Upper/Lower Cap': 'Upper_Lower_Cap',
            '52 Week High': '52W_High',
            '52 Week Low': '52W_Low',
            'High': 'High',
            'Low': 'Low'
        }
        
        for title, key in fields.items():
            tag = snapshot_table.find('strong', title=lambda x: x and title in x)
            if tag and tag.find_next('br'):
                raw_value = tag.find_next('br').next_sibling
                if raw_value:
                    snapshot_data[key] = clean_value(str(raw_value).strip())

        # Fallback for EPS if not found
        if 'EPS' not in snapshot_data or snapshot_data['EPS'] == 0:
            eps_tag = snapshot_table.find('strong', title=lambda x: x and 'EPS' in x)
            if eps_tag and eps_tag.find_next('br'):
                raw_value = eps_tag.find_next('br').next_sibling
                if raw_value:
                    snapshot_data['EPS'] = clean_value(str(raw_value).strip())
            if 'EPS' not in snapshot_data:
                logging.warning("EPS value not found in snapshot data")
                snapshot_data['EPS'] = 0
        
        return snapshot_data
    except Exception as e:
        logging.error(f"Error in scrape_company_snapshot: {str(e)}")
        logging.debug(traceback.format_exc())
        raise

def scrape_financial_data(url):
    """Scrape financial data from the given URL"""
    logging.info(f"Starting to scrape financial data from {url}")
    try:
        response = _get_with_retry(url)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        os.makedirs('financial_data', exist_ok=True)
        
        tab_mapping = {
            'nav-statement':    'income_statement.csv',
            'nav-balance':      'balance_sheet.csv',
            'nav-cash':         'cash_flow.csv',
            'nav-ratioFinance': 'financial_ratios.csv',
            'nav-equity':       'equity.csv'
        }
        
        for tab_id, filename in tab_mapping.items():
            logging.info(f"Processing tab: {tab_id}")
            tab_content = soup.find('div', {'id': tab_id})
            if not tab_content:
                logging.warning(f"Tab content not found for {tab_id}")
                continue
                
            table = tab_content.find('table')
            if not table:
                logging.warning(f"Table not found in tab {tab_id}")
                continue

            header_cells = table.find('tr').find_all('th')
            headers = ['Metric'] + [th.text.strip() for th in header_cells[1:]]
            
            rows = []
            for tr in table.find_all('tr')[1:]:
                cells = tr.find_all(['td', 'th'])
                if cells:
                    row = [cells[0].text.strip()]
                    row.extend([clean_value(cell.text.strip()) for cell in cells[1:]])
                    if len(row) == len(headers):
                        rows.append(row)
            
            df = pd.DataFrame(rows, columns=headers)
            output_path = os.path.join('financial_data', filename)
            df.to_csv(output_path, index=False)
            logging.info(f"Saved {filename}")
            print(f"Saved {filename}")
    except Exception as e:
        logging.error(f"Error in scrape_financial_data: {str(e)}")
        logging.debug(traceback.format_exc())
        raise

def scrape_payout_data(url):
    """Scrape payout data from the given URL"""
    logging.info(f"Starting to scrape payout data from {url}")
    try:
        response = _get_with_retry(url)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        os.makedirs('financial_data', exist_ok=True)
        
        table = soup.find('table', {'id': 'company-payouts'})
        if not table:
            logging.warning("Payout table not found")
            return
            
        headers = [th.text.strip() for th in table.find('thead').find_all('th')]
        
        rows = []
        for tr in table.find('tbody').find_all('tr'):
            cells = tr.find_all('td')
            row = [cell.text.strip() for cell in cells]
            rows.append(row)
        
        df = pd.DataFrame(rows, columns=headers)
        
        numeric_columns = ['Payout %', 'Face Value']
        for col in numeric_columns:
            if col in df.columns:
                df[col] = df[col].apply(lambda x: clean_value(x) if x else 0)
        
        output_path = os.path.join('financial_data', 'payouts.csv')
        df.to_csv(output_path, index=False)
        logging.info("Saved payouts.csv")
        print("Saved payouts.csv")
    except Exception as e:
        logging.error(f"Error in scrape_payout_data: {str(e)}")
        logging.debug(traceback.format_exc())
        raise

def scrape_company_data(symbol):
    """Main function to scrape all company data"""
    symbol = symbol.strip().upper()
    logging.info(f"Starting to scrape data for company symbol: {symbol}")
    
    os.makedirs('financial_data', exist_ok=True)
    
    base_url      = "https://sarmaaya.pk"
    financial_url = f"{base_url}/ajax/widgets/all_financials.php?symbol={symbol}"
    payout_url    = f"{base_url}/ajax/widgets/company_payouts.php?symbol={symbol}"
    company_url   = f"{base_url}/psx/company/{symbol}"
    
    try:
        logging.info(f"Requesting company page: {company_url}")
        response = _get_with_retry(company_url)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        snapshot_data = scrape_company_snapshot(soup)
        if not snapshot_data:
            logging.warning("No snapshot data was retrieved")
        
        snapshot_df   = pd.DataFrame([snapshot_data])
        snapshot_path = os.path.join('financial_data', 'company_snapshot.csv')
        snapshot_df.to_csv(snapshot_path, index=False)
        logging.info("Saved company_snapshot.csv")
        print("Saved company_snapshot.csv")
        
        scrape_financial_data(financial_url)
        scrape_payout_data(payout_url)
        
        logging.info(f"Data scraping for {symbol} completed successfully!")
        
    except requests.RequestException as e:
        logging.error(f"Network error for {symbol}: {str(e)}")
        logging.debug(traceback.format_exc())
        raise
    except Exception as e:
        logging.error(f"Unexpected error for {symbol}: {str(e)}")
        logging.debug(traceback.format_exc())
        raise

if __name__ == "__main__":
    try:
        symbol = input("Enter stock symbol (default: MARI): ").strip() or "MARI"
        scrape_company_data(symbol)
    except Exception as e:
        logging.error(f"Script failed: {str(e)}")
        logging.debug(traceback.format_exc())
