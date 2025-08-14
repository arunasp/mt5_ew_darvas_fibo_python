"""
ew_darvas_server.py

HTTP server that uses mt5_python_lib package to fetch MT5 OHLC using a timeframe
provided by the caller (query param 'tf'), compute Darvas boxes, Elliott patterns
and fibonacci levels and return the compact text payload.

Run: python ew_darvas_server.py
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
import MetaTrader5 as mt5
import traceback

from mt5_python_lib.mt5_client import MT5Client
from mt5_python_lib.darvas_detector import DarvasBoxDetector
from mt5_python_lib.elliott_detector import ElliottWaveDetector

HOST = "127.0.0.1"
PORT = 5000

DEFAULT_COUNT = 1200
DEFAULT_TF = mt5.TIMEFRAME_H1

# mapping common textual timeframes and minute values to mt5 constants
TF_MAP = {
    "M1": mt5.TIMEFRAME_M1,
    "M5": mt5.TIMEFRAME_M5,
    "M15": mt5.TIMEFRAME_M15,
    "M30": mt5.TIMEFRAME_M30,
    "H1": mt5.TIMEFRAME_H1,
    "H4": mt5.TIMEFRAME_H4,
    "D1": mt5.TIMEFRAME_D1,
    "W1": mt5.TIMEFRAME_W1,
    "MN1": mt5.TIMEFRAME_MN1,
    "1": mt5.TIMEFRAME_M1,
    "5": mt5.TIMEFRAME_M5,
    "15": mt5.TIMEFRAME_M15,
    "30": mt5.TIMEFRAME_M30,
    "60": mt5.TIMEFRAME_H1,
    "240": mt5.TIMEFRAME_H4,
    "1440": mt5.TIMEFRAME_D1
}

def parse_timeframe(tf_raw):
    """
    Accepts strings like 'H1','M5','60' or numeric mt5 constants.
    Returns an mt5 timeframe constant or DEFAULT_TF if unable to parse.
    """
    if not tf_raw:
        return DEFAULT_TF
    tf = str(tf_raw).strip().upper()
    # direct mapping (common)
    if tf in TF_MAP:
        return TF_MAP[tf]
    # numeric string (try int)
    try:
        iv = int(tf)
        # if matches known mapping return mapped constant (minutes)
        if str(iv) in TF_MAP:
            return TF_MAP[str(iv)]
        # if appears to be a mt5 timeframe constant numeric value, return it
        # many mt5 constants are small ints; we try to return iv directly
        return iv
    except Exception:
        pass
    # fallback
    return DEFAULT_TF

def build_payload(boxes, patterns, fibs):
    """
    Build the compact textual payload:
    BOXES
    start_time|end_time|top|bottom|trend|start_idx|end_idx
    ENDBOXES
    WAVES
    pattern_idx|node_idx|wave_number|time|price|box_idx|type
    ENDWAVES
    FIBS
    pattern_idx|wave_ref|level_pct|level_price
    ENDFIBS
    """
    lines = []
    lines.append("BOXES")
    for b in boxes:
        sdt = b.start_time.strftime("%Y.%m.%d %H:%M") if b.start_time is not None else ""
        edt = b.end_time.strftime("%Y.%m.%d %H:%M") if b.end_time is not None else ""
        lines.append(f"{sdt}|{edt}|{b.top:.8f}|{b.bottom:.8f}|{b.trend}|{b.start_idx}|{b.end_idx}")
    lines.append("ENDBOXES")

    lines.append("WAVES")
    for pi, pat in enumerate(patterns):
        for ni, node in enumerate(pat.nodes):
            tstr = node.time.strftime("%Y.%m.%d %H:%M") if node.time is not None else ""
            wave_number = ni + 1
            lines.append(f"{pi}|{ni}|{wave_number}|{tstr}|{node.price:.8f}|{node.box_idx}|{node.kind}")
    lines.append("ENDWAVES")

    lines.append("FIBS")
    for f in fibs:
        lines.append(f"{f.pattern_idx}|{f.wave_ref}|{f.level_pct:.6f}|{f.level_price:.8f}")
    lines.append("ENDFIBS")
    return "\n".join(lines)


class EWHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path != "/darvas":
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not found")
            return

        qs = parse_qs(parsed.query)
        tf_raw = qs.get("tf", [None])[0]       # e.g. H1, M5, 60
        symbol = qs.get("symbol", [None])[0]
        count_raw = qs.get("count", [None])[0]

        timeframe = parse_timeframe(tf_raw)
        try:
            count = int(count_raw) if count_raw is not None else DEFAULT_COUNT
        except Exception:
            count = DEFAULT_COUNT

        try:
            client = MT5Client()
            client.initialize()
            if symbol is None or symbol == "":
                symbol = client.default_symbol()

            # fetch OHLC using requested timeframe and count
            df = client.copy_rates(symbol, timeframe, count)

            darvas = DarvasBoxDetector(df)
            boxes = darvas.detect_boxes()
            ew = ElliottWaveDetector(boxes, df)
            points = ew.prepare_wave_points()
            patterns = ew.detect_5wave_impulses()
            fibs = ew.compute_fibonacci_levels()

            body = build_payload(boxes, patterns, fibs).encode("utf-8")
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except Exception as e:
            tb = traceback.format_exc()
            err = f"ERROR: {str(e)}\n{tb}"
            self.send_response(500)
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.end_headers()
            self.wfile.write(err.encode("utf-8"))
        finally:
            try:
                mt5.shutdown()
            except Exception:
                pass


def run_server(host=HOST, port=PORT):
    server = HTTPServer((host, port), EWHandler)
    print(f"Server running at http://{host}:{port}/darvas")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Shutting down server.")
        server.server_close()


if __name__ == "__main__":
    run_server()
