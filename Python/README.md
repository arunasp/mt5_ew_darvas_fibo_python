# mt5_python_lib

mt5_python_lib is a small Python package that provides Darvas box detection and simple Elliott wave detection using OHLC data fetched from a running MetaTrader 5 (MT5) terminal. The package includes a lightweight HTTP server that exposes computed boxes, wave nodes and Fibonacci retracement levels for use by MetaTrader 5 clients (e.g., MQL5 indicators using WebRequest).

This repackaging includes:
- mt5_python_lib package:
  - types.py
  - mt5_client.py
  - darvas_detector.py
  - elliott_detector.py
- darvas_server.py - HTTP server entrypoint
- README.md (this file)
- requirements.txt - pip dependencies
- conversation_log.txt - chat conversation log (for traceability)

Requirements
- Python 3.13.6 or later
- MetaTrader 5 terminal installed and running on the same machine
- Python packages: pandas, numpy, MetaTrader5

Installation
1. Create a virtual environment (recommended)
   python -m venv venv
   source venv/bin/activate   # on Windows use: venv\Scripts\activate

2. Install dependencies
   pip install -r requirements.txt

Usage
1. Start MetaTrader 5 terminal.
2. Make sure the terminal is logged in and symbols are available.
3. Add the server URL to MT5 allowed WebRequest addresses if your MQL5 client will call the server:
   - Tools  Options  Expert Advisors  Allow WebRequest for listed URL
   - Add: http://127.0.0.1 (or http://127.0.0.1:5000)
4. Run the server:
   python darvas_server.py
   - Server default: http://127.0.0.1:5000/darvas
   - The server will fetch the most recent H1 bars (default) from MT5, compute Darvas boxes and Elliott patterns and return a compact textual payload.
5. Use the MQL5 indicator/script to WebRequest that endpoint and parse the returned payload for plotting.

Files of interest
- mt5_python_lib/ - package modules implementing detection logic
- darvas_server.py - simple HTTP server (uses builtin http.server) returning compact text
- conversation_log.txt - full conversation log used during development (for traceability)
- requirements.txt - dependency list

Notes & next steps
- The detection rules are intentionally simple and meant as a starting point. You can improve:
  - Wave validation (length, Fibonacci ratio acceptance)
  - Box smoothing or filtering (minimum size, duration)
  - Replace text payload with JSON and use a JSON parser in MQL5 (or send simpler encoded binary)
- For production use consider running a more robust web server (FastAPI + uvicorn) and securing access.
- If you prefer JSON output instead of the compact text format, I can provide that and an updated MQL5 parser.

License
- Provided as-is for your use. Adapt and reuse as needed.
