# ew_darvas_server.py
"""
HTTP server that uses mt5_python_lib package to fetch MT5 OHLC, compute Darvas boxes,
Elliott patterns and fibonacci levels and return a compact text payload.

Run: python darvas_server.py
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse
import MetaTrader5 as mt5

from mt5_python_lib.mt5_client import MT5Client
from mt5_python_lib.darvas_detector import DarvasBoxDetector
from mt5_python_lib.elliott_detector import ElliottWaveDetector

HOST = "127.0.0.1"
PORT = 5000

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

class DarvasHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path != "/darvas":
            self.send_response(404); self.end_headers(); self.wfile.write(b"Not found"); return
        try:
            client = MT5Client()
            client.initialize()
            symbol = client.default_symbol()
            # fetch OHLC; timeframe fixed to H1 here but you can add query params if needed
            df = client.copy_rates(symbol, mt5.TIMEFRAME_H1, 1200)
            darvas = DarvasBoxDetector(df)
            boxes = darvas.detect_boxes()
            ew = ElliottWaveDetector(boxes, df)
            points = ew.prepare_wave_points()
            patterns = ew.detect_5wave_impulses()
            fibs = ew.compute_fibonacci_levels()

            body = build_payload(boxes, patterns, fibs).encode("utf-8")
            self.send_response(200)
            self.send_header('Content-Type','text/plain; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except Exception as e:
            err = f"ERROR: {str(e)}"
            self.send_response(500)
            self.send_header('Content-Type','text/plain; charset=utf-8')
            self.end_headers()
            self.wfile.write(err.encode("utf-8"))

def run_server(host=HOST, port=PORT):
    server = HTTPServer((host, port), DarvasHandler)
    print(f"Server running at http://{host}:{port}/darvas")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Shutting down server.")
        server.server_close()

if __name__ == "__main__":
    run_server()
