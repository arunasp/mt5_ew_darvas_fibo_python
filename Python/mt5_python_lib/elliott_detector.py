# mt5_python_lib/elliott_detector.py
from __future__ import annotations
from typing import List
import pandas as pd
from .types import DarvasBox, WaveNode, Pattern, FibLine

class ElliottWaveDetector:
    """
    Build wave points from Darvas boxes, detect simple 5-wave impulses (direction pattern + - + - +),
    and compute Fibonacci retracement levels for wave2 (from wave1) and wave4 (from wave3).
    """

    FIB_LEVELS = [0.236, 0.382, 0.5, 0.618, 0.786]

    def __init__(self, boxes: List[DarvasBox], df: pd.DataFrame) -> None:
        self.boxes = boxes
        self.df = df.reset_index(drop=True).copy()
        self.points: List[WaveNode] = []
        self.patterns: List[Pattern] = []
        self.fib_lines: List[FibLine] = []

    def prepare_wave_points(self) -> List[WaveNode]:
        """
        For each box, add its top and bottom points and include previous box extremas for continuity.
        Sort points by time ascending.
        """
        pts: list[WaveNode] = []
        for i, b in enumerate(self.boxes):
            # clamp indices
            si = max(0, min(len(self.df) - 1, b.start_idx))
            ei = max(0, min(len(self.df) - 1, b.end_idx))
            t_start = self.df.iloc[si]['datetime'] if 'datetime' in self.df.columns else None
            t_end = self.df.iloc[ei]['datetime'] if 'datetime' in self.df.columns else None
            pts.append(WaveNode(price=b.top, time=t_start, box_idx=i, kind='top'))
            pts.append(WaveNode(price=b.bottom, time=t_end, box_idx=i, kind='bottom'))
            if i > 0:
                pb = self.boxes[i - 1]
                psi = max(0, min(len(self.df) - 1, pb.start_idx))
                pei = max(0, min(len(self.df) - 1, pb.end_idx))
                pts.append(WaveNode(price=pb.top, time=self.df.iloc[psi]['datetime'], box_idx=i - 1, kind='prev_top'))
                pts.append(WaveNode(price=pb.bottom, time=self.df.iloc[pei]['datetime'], box_idx=i - 1, kind='prev_bottom'))

        # dedupe by (price,time) and sort by time
        seen = set()
        unique = []
        for p in pts:
            tkey = None
            if p.time is not None:
                tkey = pd.Timestamp(p.time).to_datetime64()
            key = (p.price, None if tkey is None else int(tkey.astype('datetime64[s]').astype('int64')))
            if key not in seen:
                seen.add(key)
                unique.append(p)

        # Sort by time; missing times go to end
        def time_key(x: WaveNode):
            if x.time is None:
                return pd.Timestamp.max
            return pd.Timestamp(x.time)

        unique_sorted = sorted(unique, key=time_key)

        # assign node indices
        for idx, node in enumerate(unique_sorted):
            node.node_index = idx

        self.points = unique_sorted
        return self.points

    def detect_5wave_impulses(self) -> List[Pattern]:
        self.patterns = []
        prices = [p.price for p in self.points]
        n = len(prices)
        if n < 6:
            return []

        dirs: list[int] = []
        for i in range(1, n):
            d = prices[i] - prices[i - 1]
            dirs.append(1 if d > 0 else (-1 if d < 0 else 0))

        for s in range(0, len(dirs) - 4):
            if dirs[s:s + 5] == [1, -1, 1, -1, 1]:
                nodes = [self.points[j] for j in range(s, s + 6)]
                self.patterns.append(Pattern(nodes=nodes))

        return self.patterns

    def compute_fibonacci_levels(self) -> List[FibLine]:
        fibs: List[FibLine] = []
        for pi, pat in enumerate(self.patterns):
            p0 = pat.nodes[0].price
            p1 = pat.nodes[1].price
            p2 = pat.nodes[2].price
            p3 = pat.nodes[3].price
            # wave2 retrace (based on p0->p1)
            for r in self.FIB_LEVELS:
                lvl = p1 + (p0 - p1) * r
                fibs.append(FibLine(pattern_idx=pi, wave_ref=1, level_pct=r, level_price=float(lvl)))
            # wave4 retrace (based on p2->p3)
            for r in self.FIB_LEVELS:
                lvl = p3 + (p2 - p3) * r
                fibs.append(FibLine(pattern_idx=pi, wave_ref=3, level_pct=r, level_price=float(lvl)))
        self.fib_lines = fibs
        return fibs
