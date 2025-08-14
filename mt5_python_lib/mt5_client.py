# mt5_python_lib/mt5_client.py
from __future__ import annotations
from typing import Tuple
import MetaTrader5 as mt5
import pandas as pd

class MT5Client:
    """
    Simple wrapper to fetch OHLC from a running MT5 terminal.
    Ensure the terminal is running before calling.
    """

    def __init__(self) -> None:
        self._initialized = False

    def initialize(self) -> None:
        if not self._initialized:
            if not mt5.initialize():
                raise RuntimeError("MetaTrader5.initialize() failed. Ensure MT5 terminal is running.")
            self._initialized = True

    def shutdown(self) -> None:
        if self._initialized:
            try:
                mt5.shutdown()
            finally:
                self._initialized = False

    def copy_rates(self, symbol: str, timeframe: int, count: int = 1200) -> pd.DataFrame:
        """
        Fetch recent rates ascending (oldest -> newest) as DataFrame with
        datetime, Open, High, Low, Close columns.
        """
        self.initialize()
        rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, count)
        if rates is None or len(rates) == 0:
            raise RuntimeError(f"Could not fetch rates for symbol={symbol} timeframe={timeframe}")
        df = pd.DataFrame(rates)
        df['datetime'] = pd.to_datetime(df['time'], unit='s')
        df = df[['datetime', 'open', 'high', 'low', 'close']].rename(columns={
            'open': 'Open', 'high': 'High', 'low': 'Low', 'close': 'Close'
        })
        return df

    def default_symbol(self) -> str:
        """
        Return a symbol likely available on the terminal (first symbol).
        """
        syms = mt5.symbols_get()
        if not syms:
            raise RuntimeError("No symbols available in MT5.")
        return syms[0].name
