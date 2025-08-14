# mt5_python_lib/darvas_detector.py
from __future__ import annotations
import numpy as np
import pandas as pd
from typing import List
from .types import DarvasBox

class DarvasBoxDetector:
    """
    Darvas Box state machine implementation.
    Expects DataFrame with columns ['datetime','Open','High','Low','Close'],
    ascending chronological (oldest -> newest).
    """

    def __init__(self, df: pd.DataFrame) -> None:
        df = df.reset_index(drop=True).copy()
        # accept lowercase column names as well
        for col in ['Open', 'High', 'Low', 'Close']:
            if col not in df.columns and col.lower() in df.columns:
                df[col] = df[col.lower()]
        self.df = df
        self.boxes: List[DarvasBox] = []

    def detect_boxes(self) -> List[DarvasBox]:
        highs = self.df['High'].values
        lows = self.df['Low'].values
        n = len(self.df)
        if n < 3:
            return []

        state = 0
        box_top = None
        box_bottom = None
        box_start = 0
        trend = None
        prev_breakout_price = None

        boxes: List[DarvasBox] = []
        i = 1
        while i < n:
            high = float(highs[i])
            low = float(lows[i])

            if state == 0:
                if prev_breakout_price is not None:
                    if high > prev_breakout_price:
                        box_top = high
                        box_start = i
                        trend = 'up'
                        box_bottom = None
                        state = 1
                        i += 1
                        continue
                    elif low < prev_breakout_price:
                        box_bottom = low
                        box_start = i
                        trend = 'down'
                        box_top = None
                        state = 1
                        i += 1
                        continue
                    else:
                        i += 1
                        continue
                else:
                    prev_high = float(highs[i - 1])
                    prev_low = float(lows[i - 1])
                    if high > prev_high:
                        box_top = high
                        box_start = i
                        trend = 'up'
                        box_bottom = None
                        state = 1
                        i += 1
                        continue
                    elif low < prev_low:
                        box_bottom = low
                        box_start = i
                        trend = 'down'
                        box_top = None
                        state = 1
                        i += 1
                        continue
                    else:
                        i += 1
                        continue

            else:  # state == 1, confirming box
                if trend == 'up':
                    if high > box_top:
                        box_top = high
                        box_start = i
                        box_bottom = None
                        i += 1
                        continue
                    window_lows = lows[box_start:i + 1]
                    new_bottom = float(np.min(window_lows))
                    if box_bottom is None or new_bottom < box_bottom:
                        box_bottom = new_bottom
                    if (i + 1 < n) and (lows[i + 1] < box_bottom):
                        box_end = i
                        start_time = pd.Timestamp(self.df.iloc[box_start]['datetime'])
                        end_time = pd.Timestamp(self.df.iloc[box_end]['datetime'])
                        boxes.append(DarvasBox(top=float(box_top),
                                               bottom=float(box_bottom),
                                               start_idx=int(box_start),
                                               end_idx=int(box_end),
                                               trend='up',
                                               start_time=start_time.to_pydatetime(),
                                               end_time=end_time.to_pydatetime()))
                        prev_breakout_price = float(box_top)
                        box_top = box_bottom = None
                        trend = None
                        state = 0
                        i += 1
                        continue
                    else:
                        i += 1
                        continue
                else:  # down trend
                    if low < box_bottom:
                        box_bottom = low
                        box_start = i
                        box_top = None
                        i += 1
                        continue
                    window_highs = highs[box_start:i + 1]
                    new_top = float(np.max(window_highs))
                    if box_top is None or new_top > box_top:
                        box_top = new_top
                    if (i + 1 < n) and (highs[i + 1] > box_top):
                        box_end = i
                        start_time = pd.Timestamp(self.df.iloc[box_start]['datetime'])
                        end_time = pd.Timestamp(self.df.iloc[box_end]['datetime'])
                        boxes.append(DarvasBox(top=float(box_top),
                                               bottom=float(box_bottom),
                                               start_idx=int(box_start),
                                               end_idx=int(box_end),
                                               trend='down',
                                               start_time=start_time.to_pydatetime(),
                                               end_time=end_time.to_pydatetime()))
                        prev_breakout_price = float(box_bottom)
                        box_top = box_bottom = None
                        trend = None
                        state = 0
                        i += 1
                        continue
                    else:
                        i += 1
                        continue

        # finalize incomplete box
        if state == 1 and box_top is not None and box_bottom is not None:
            box_end = n - 1
            start_time = pd.Timestamp(self.df.iloc[box_start]['datetime'])
            end_time = pd.Timestamp(self.df.iloc[box_end]['datetime'])
            boxes.append(DarvasBox(top=float(box_top),
                                   bottom=float(box_bottom),
                                   start_idx=int(box_start),
                                   end_idx=int(box_end),
                                   trend=trend or "",
                                   start_time=start_time.to_pydatetime(),
                                   end_time=end_time.to_pydatetime()))
        self.boxes = boxes
        return boxes
