# mt5_python_lib/types.py
from __future__ import annotations
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

@dataclass(slots=True)
class DarvasBox:
    top: float
    bottom: float
    start_idx: int
    end_idx: int
    trend: str  # 'up' or 'down'
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None

@dataclass(slots=True)
class WaveNode:
    price: float
    time: Optional[datetime]
    box_idx: int
    kind: str  # 'top','bottom','prev_top','prev_bottom'
    node_index: Optional[int] = None

@dataclass(slots=True)
class Pattern:
    nodes: list[WaveNode]  # typically 6 nodes forming a 5-wave impulse

@dataclass(slots=True)
class FibLine:
    pattern_idx: int
    wave_ref: int  # 1 or 3
    level_pct: float
    level_price: float
