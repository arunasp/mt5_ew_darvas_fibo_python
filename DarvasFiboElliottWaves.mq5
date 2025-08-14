//+------------------------------------------------------------------+
//| DarvasFiboElliottWaves.mq5                                      |
//| MQL5-only implementation: queries server, draws objects, exposes |
//| data via indicator buffers and plots 5 wave lines                |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 15
#property indicator_plots   15

// Buffer labels (1-based)
#property indicator_label1  "BOX_TOP"
#property indicator_label2  "BOX_BOTTOM"
#property indicator_label3  "BOX_T1"
#property indicator_label4  "BOX_T2"
#property indicator_label5  "NODE_PRICE"
#property indicator_label6  "NODE_TIME"
#property indicator_label7  "NODE_BOXIDX"
#property indicator_label8  "FIB_PRICE"
#property indicator_label9  "FIB_PCT"
#property indicator_label10 "FIB_PATTERNIDX"
#property indicator_label11 "WAVE1_LINE"
#property indicator_label12 "WAVE2_LINE"
#property indicator_label13 "WAVE3_LINE"
#property indicator_label14 "WAVE4_LINE"
#property indicator_label15 "WAVE5_LINE"

// First 10 are hidden data buffers, last 5 are drawing plots (lines)
#property indicator_type1   DRAW_NONE
#property indicator_type2   DRAW_NONE
#property indicator_type3   DRAW_NONE
#property indicator_type4   DRAW_NONE
#property indicator_type5   DRAW_NONE
#property indicator_type6   DRAW_NONE
#property indicator_type7   DRAW_NONE
#property indicator_type8   DRAW_NONE
#property indicator_type9   DRAW_NONE
#property indicator_type10  DRAW_NONE
#property indicator_type11  DRAW_LINE
#property indicator_type12  DRAW_LINE
#property indicator_type13  DRAW_LINE
#property indicator_type14  DRAW_LINE
#property indicator_type15  DRAW_LINE

//--- Inputs
input string ServerUrl = "http://127.0.0.1:5000/darvas"; // server endpoint (allow in Tools->Options->Expert Advisors -> Allow WebRequest)
input int    RequestTimeoutMs = 5000;
input int    RequestIntervalSec = 60;   // polling interval seconds
input color  BoxColor = clrDodgerBlue;
input color  WaveColor = clrYellow;
input color  FibColor = clrOrange;

// Max counts (indicator inputs)
input int MaxBoxes = 1000;
input int MaxNodes = 1000;
input int MaxFibs  = 1000;

//--- Buffers
double bufBoxTop[];
double bufBoxBottom[];
double bufBoxT1[];
double bufBoxT2[];
double bufNodePrice[];
double bufNodeTime[];
double bufNodeBoxIdx[];
double bufFibPrice[];
double bufFibPct[];
double bufFibPatternIdx[];
double bufWave1[];  // plotted
double bufWave2[];  // plotted
double bufWave3[];  // plotted
double bufWave4[];  // plotted
double bufWave5[];  // plotted

//--- internal state
datetime last_request_time = 0;

//--- buffer indices (0-based)
enum BufIndex
{
  BI_BOX_TOP = 0,
  BI_BOX_BOTTOM,
  BI_BOX_T1,
  BI_BOX_T2,
  BI_NODE_PRICE,
  BI_NODE_TIME,
  BI_NODE_BOXIDX,
  BI_FIB_PRICE,
  BI_FIB_PCT,
  BI_FIB_PATTERNIDX,
  BI_WAVE1,
  BI_WAVE2,
  BI_WAVE3,
  BI_WAVE4,
  BI_WAVE5
};

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  // Bind buffers (no return-check to avoid build differences)
  SetIndexBuffer(BI_BOX_TOP, bufBoxTop);
  SetIndexBuffer(BI_BOX_BOTTOM, bufBoxBottom);
  SetIndexBuffer(BI_BOX_T1, bufBoxT1);
  SetIndexBuffer(BI_BOX_T2, bufBoxT2);
  SetIndexBuffer(BI_NODE_PRICE, bufNodePrice);
  SetIndexBuffer(BI_NODE_TIME, bufNodeTime);
  SetIndexBuffer(BI_NODE_BOXIDX, bufNodeBoxIdx);
  SetIndexBuffer(BI_FIB_PRICE, bufFibPrice);
  SetIndexBuffer(BI_FIB_PCT, bufFibPct);
  SetIndexBuffer(BI_FIB_PATTERNIDX, bufFibPatternIdx);
  SetIndexBuffer(BI_WAVE1, bufWave1);
  SetIndexBuffer(BI_WAVE2, bufWave2);
  SetIndexBuffer(BI_WAVE3, bufWave3);
  SetIndexBuffer(BI_WAVE4, bufWave4);
  SetIndexBuffer(BI_WAVE5, bufWave5);

  // Style wave plots using MQL5 plotting API
  PlotIndexSetInteger(BI_WAVE1, PLOT_DRAW_TYPE, DRAW_LINE);
  PlotIndexSetInteger(BI_WAVE1, PLOT_LINE_STYLE, STYLE_SOLID);
  PlotIndexSetInteger(BI_WAVE1, PLOT_LINE_WIDTH, 2);
  PlotIndexSetInteger(BI_WAVE1, PLOT_LINE_COLOR, clrAqua);

  PlotIndexSetInteger(BI_WAVE2, PLOT_DRAW_TYPE, DRAW_LINE);
  PlotIndexSetInteger(BI_WAVE2, PLOT_LINE_STYLE, STYLE_SOLID);
  PlotIndexSetInteger(BI_WAVE2, PLOT_LINE_WIDTH, 2);
  PlotIndexSetInteger(BI_WAVE2, PLOT_LINE_COLOR, clrLime);

  PlotIndexSetInteger(BI_WAVE3, PLOT_DRAW_TYPE, DRAW_LINE);
  PlotIndexSetInteger(BI_WAVE3, PLOT_LINE_STYLE, STYLE_SOLID);
  PlotIndexSetInteger(BI_WAVE3, PLOT_LINE_WIDTH, 2);
  PlotIndexSetInteger(BI_WAVE3, PLOT_LINE_COLOR, clrYellow);

  PlotIndexSetInteger(BI_WAVE4, PLOT_DRAW_TYPE, DRAW_LINE);
  PlotIndexSetInteger(BI_WAVE4, PLOT_LINE_STYLE, STYLE_SOLID);
  PlotIndexSetInteger(BI_WAVE4, PLOT_LINE_WIDTH, 2);
  PlotIndexSetInteger(BI_WAVE4, PLOT_LINE_COLOR, clrOrange);

  PlotIndexSetInteger(BI_WAVE5, PLOT_DRAW_TYPE, DRAW_LINE);
  PlotIndexSetInteger(BI_WAVE5, PLOT_LINE_STYLE, STYLE_SOLID);
  PlotIndexSetInteger(BI_WAVE5, PLOT_LINE_WIDTH, 2);
  PlotIndexSetInteger(BI_WAVE5, PLOT_LINE_COLOR, clrMagenta);

  // Initialize buffers
  ClearAllBuffers();

  // Start polling timer
  EventSetTimer(RequestIntervalSec);
  PrintFormat("DarvasFiboElliottWaves initialized. ServerUrl=%s MaxBoxes=%d MaxNodes=%d MaxFibs=%d", ServerUrl, MaxBoxes, MaxNodes, MaxFibs);
  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  EventKillTimer();
  // leave objects on chart by default
}

//+------------------------------------------------------------------+
//| OnCalculate - not used for per-bar calculation here              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
  // Indicator serves as data channel; no per-bar calculaion required
  return(rates_total);
}

//+------------------------------------------------------------------+
//| Timer: Poll server                                               |
//+------------------------------------------------------------------+
void OnTimer()
{
  // throttle by RequestIntervalSec
  if (TimeCurrent() - last_request_time < RequestIntervalSec) return;
  last_request_time = TimeCurrent();
  RequestAndRender();
}

//+------------------------------------------------------------------+
//| Build tf string from Period()                                    |
//+------------------------------------------------------------------+
string PeriodToTfString(int period)
{
  switch (period)
  {
    case PERIOD_M1:  return "M1";
    case PERIOD_M5:  return "M5";
    case PERIOD_M15: return "M15";
    case PERIOD_M30: return "M30";
    case PERIOD_H1:  return "H1";
    case PERIOD_H4:  return "H4";
    case PERIOD_D1:  return "D1";
    case PERIOD_W1:  return "W1";
    case PERIOD_MN1: return "MN1";
    default: return "H1";
  }
}

//+------------------------------------------------------------------+
//| Request server and parse response                                |
//+------------------------------------------------------------------+
void RequestAndRender()
{
  ResetLastError();

  string tf = PeriodToTfString(Period());
  string sym = Symbol();
  int count = 1200;

  string url = ServerUrl + "?tf=" + tf + "&symbol=" + sym + "&count=" + IntegerToString(count);

  // prepare empty request data (GET)
  uchar request_data[];
  ArrayResize(request_data, 0);

  // receive response here
  uchar response_data[];
  ArrayResize(response_data, 0);
  string response_headers = "";

  // Correct overload: method, url, headers, timeout, request_data[], response_data[], response_headers
  int http_status = WebRequest("GET", url, "", RequestTimeoutMs, request_data, response_data, response_headers);

  if (http_status == -1)
  {
    int err = GetLastError();
    PrintFormat("WebRequest failed. Error=%d. Ensure %s is allowed in Tools->Options->Expert Advisors -> Allow WebRequest for listed URL", err, ServerUrl);
    ResetLastError();
    return;
  }

  // convert uchar[] to string (UTF-8)
  string response = "";
  if (ArraySize(response_data) > 0)
    response = CharArrayToString(response_data, 0, -1);

  if (http_status >= 400)
  {
    PrintFormat("HTTP %d response from server: %s\nResponse headers: %s", http_status, response, response_headers);
    return;
  }

  // successful response
  ParseDarvasPayload(response);
}

//+------------------------------------------------------------------+
//| Clear all buffers to EMPTY_VALUE                                 |
//+------------------------------------------------------------------+
void ClearAllBuffers()
{
  int bcount = Bars;
  if (bcount <= 0) return;
  for (int i = 0; i < bcount; ++i)
  {
    bufBoxTop[i] = EMPTY_VALUE;
    bufBoxBottom[i] = EMPTY_VALUE;
    bufBoxT1[i] = EMPTY_VALUE;
    bufBoxT2[i] = EMPTY_VALUE;
    bufNodePrice[i] = EMPTY_VALUE;
    bufNodeTime[i] = EMPTY_VALUE;
    bufNodeBoxIdx[i] = EMPTY_VALUE;
    bufFibPrice[i] = EMPTY_VALUE;
    bufFibPct[i] = EMPTY_VALUE;
    bufFibPatternIdx[i] = EMPTY_VALUE;
    bufWave1[i] = EMPTY_VALUE;
    bufWave2[i] = EMPTY_VALUE;
    bufWave3[i] = EMPTY_VALUE;
    bufWave4[i] = EMPTY_VALUE;
    bufWave5[i] = EMPTY_VALUE;
  }
}

//+------------------------------------------------------------------+
//| Delete DARV_ prefixed objects                                    |
//+------------------------------------------------------------------+
void DeleteDarvObjects()
{
  string prefix = "DARV_";
  int total = ObjectsTotal(0);
  for (int i = total - 1; i >= 0; --i)
  {
    string name = ObjectName(0, i);
    if (StringFind(name, prefix) == 0)
      ObjectDelete(0, name);
  }
}

//+------------------------------------------------------------------+
//| Parse payload and populate buffers / objects                     |
//+------------------------------------------------------------------+
void ParseDarvasPayload(const string payload)
{
  // remove previous objects and buffers
  DeleteDarvObjects();
  ClearAllBuffers();

  int bars = Bars;
  if (bars <= 1)
  {
    Print("Not enough bars to store buffers.");
    return;
  }

  int effMaxBoxes = MathMin(MaxBoxes, bars - 1);
  int effMaxNodes = MathMin(MaxNodes, bars - 1);
  int effMaxFibs = MathMin(MaxFibs, bars - 1);

  string lines[];
  int count = StringSplit(payload, '\n', lines, WHOLE_ARRAY);
  if (count == 0)
  {
    Print("Empty payload from server.");
    return;
  }

  int i = 0;
  // Parse BOXES section
  if (i < count && StringTrim(lines[i]) == "BOXES") i++;
  int box_idx = 0;
  while (i < count && StringTrim(lines[i]) != "ENDBOXES")
  {
    string line = StringTrim(lines[i++]);
    if (StringLen(line) == 0) continue;
    string parts[];
    int p = StringSplit(line, '|', parts, WHOLE_ARRAY);
    if (p >= 7)
    {
      string sdt = parts[0];
      string edt = parts[1];
      double top = StringToDouble(parts[2]);
      double bottom = StringToDouble(parts[3]);
      //string trend = parts[4];
      int sidx = (int)StringToInteger(parts[5]);
      int eidx = (int)StringToInteger(parts[6]);

      datetime t1 = ParseDatetimeSafe(sdt);
      datetime t2 = ParseDatetimeSafe(edt);
      if (t1 == 0) t1 = Time[Bars - 1];
      if (t2 == 0) t2 = Time[0];

      // Draw rectangle
      string box_name = StringFormat("DARV_BOX_%d", box_idx);
      if (ObjectCreate(0, box_name, OBJ_RECTANGLE, 0, t1, top, t2, bottom))
      {
        ObjectSetInteger(0, box_name, OBJPROP_COLOR, BoxColor);
        ObjectSetInteger(0, box_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, box_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, box_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, box_name, OBJPROP_SELECTABLE, false);
      }

      // Store in data buffers at index = box_idx (entry indexing)
      if (box_idx < effMaxBoxes && box_idx < Bars)
      {
        int idx = box_idx;
        bufBoxTop[idx] = top;
        bufBoxBottom[idx] = bottom;
        bufBoxT1[idx] = (double)t1;
        bufBoxT2[idx] = (double)t2;
      }
      ++box_idx;
    }
  }

  // Move to WAVES
  while (i < count && StringTrim(lines[i]) != "WAVES") i++;
  if (i < count && StringTrim(lines[i]) == "WAVES") i++;

  // Parse WAVES
  int pattern_count = 0;
  int node_idx = 0;
  while (i < count && StringTrim(lines[i]) != "ENDWAVES")
  {
    string line = StringTrim(lines[i++]);
    if (StringLen(line) == 0) continue;
    string parts[];
    int p = StringSplit(line, '|', parts, WHOLE_ARRAY);
    if (p >= 7)
    {
      int pattern_idx = (int)StringToInteger(parts[0]);
      int node_i = (int)StringToInteger(parts[1]);
      int wave_number = (int)StringToInteger(parts[2]); // 1..5
      string tstr = parts[3];
      double price = StringToDouble(parts[4]);
      int boxidx = (int)StringToInteger(parts[5]);
      // string kind = parts[6];

      datetime tnode = ParseDatetimeSafe(tstr);
      if (tnode == 0) tnode = Time[0];

      // Create text and arrow
      string node_name = StringFormat("DARV_PAT%d_NODE%d", pattern_idx, node_i);
      if (ObjectCreate(0, node_name, OBJ_TEXT, 0, tnode, price))
      {
        ObjectSetString(0, node_name, OBJPROP_TEXT, StringFormat("%d", wave_number));
        ObjectSetInteger(0, node_name, OBJPROP_COLOR, WaveColor);
        ObjectSetInteger(0, node_name, OBJPROP_FONTSIZE, 9);
        ObjectSetInteger(0, node_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
        ObjectSetInteger(0, node_name, OBJPROP_SELECTABLE, false);
      }

      string arrow_name = StringFormat("DARV_PAT%d_NODE%d_ARROW", pattern_idx, node_i);
      if (ObjectCreate(0, arrow_name, OBJ_ARROW, 0, tnode, price))
      {
        ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, WaveColor);
        ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, 233);
        ObjectSetInteger(0, arrow_name, OBJPROP_SELECTABLE, false);
      }

      // Store in sequential data buffers (entry index)
      if (node_idx < effMaxNodes && node_idx < Bars)
      {
        int idx = node_idx;
        bufNodePrice[idx] = price;
        bufNodeTime[idx] = (double)tnode;
        bufNodeBoxIdx[idx] = (double)boxidx;
      }
      ++node_idx;
      if (pattern_idx + 1 > pattern_count) pattern_count = pattern_idx + 1;

      // Also plot wave lines: place price at bar shift corresponding to tnode
      if (wave_number >= 1 && wave_number <= 5)
      {
        int shift = iBarShift(Symbol(), Period(), tnode, false);
        if (shift >= 0 && shift < Bars)
        {
          switch (wave_number)
          {
            case 1: bufWave1[shift] = price; break;
            case 2: bufWave2[shift] = price; break;
            case 3: bufWave3[shift] = price; break;
            case 4: bufWave4[shift] = price; break;
            case 5: bufWave5[shift] = price; break;
          }
        }
      }
    }
  }

  // Move to FIBS
  while (i < count && StringTrim(lines[i]) != "FIBS") i++;
  if (i < count && StringTrim(lines[i]) == "FIBS") i++;

  // Parse FIBS
  int fib_idx = 0;
  while (i < count && StringTrim(lines[i]) != "ENDFIBS")
  {
    string line = StringTrim(lines[i++]);
    if (StringLen(line) == 0) continue;
    string parts[];
    int p = StringSplit(line, '|', parts, WHOLE_ARRAY);
    if (p >= 4)
    {
      int pattern_idx = (int)StringToInteger(parts[0]);
      int wave_ref = (int)StringToInteger(parts[1]);
      double level_pct = StringToDouble(parts[2]);
      double level_price = StringToDouble(parts[3]);

      // Draw horizontal line
      string fib_name = StringFormat("DARV_PAT%d_FIB_%d", pattern_idx, fib_idx);
      if (ObjectCreate(0, fib_name, OBJ_HLINE, 0, TimeCurrent(), level_price))
      {
        ObjectSetInteger(0, fib_name, OBJPROP_COLOR, FibColor);
        ObjectSetInteger(0, fib_name, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, fib_name, OBJPROP_SELECTABLE, false);
        ObjectSetString(0, fib_name, OBJPROP_TEXT, StringFormat("P%d R%d %.3f", pattern_idx, wave_ref, level_pct));
      }

      // Store in fib buffers
      if (fib_idx < effMaxFibs && fib_idx < Bars)
      {
        int idx = fib_idx;
        bufFibPrice[idx] = level_price;
        bufFibPct[idx] = level_pct;
        bufFibPatternIdx[idx] = (double)pattern_idx;
      }
      ++fib_idx;
    }
  }

  PrintFormat("Parsed %d boxes, %d nodes, %d fibs (buffers filled up to effective maxima).", box_idx, node_idx, fib_idx);
}

//+------------------------------------------------------------------+
//| Safe datetime parse (expects "YYYY.MM.DD HH:MM" or similar)      |
//+------------------------------------------------------------------+
datetime ParseDatetimeSafe(const string s)
{
  string str = StringTrim(s);
  if (StringLen(str) == 0) return 0;
  datetime dt = StringToTime(str);
  if (dt == 0)
  {
    string tmp = StringReplace(str, ".", "-");
    dt = StringToTime(tmp);
  }
  return dt;
}
//+------------------------------------------------------------------+
