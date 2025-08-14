#property indicator_chart_window
#property indicator_buffers 15
#property indicator_plots   15

// Buffer labels (1-based in properties; buffer indices are 0-based)
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

// Types: first 10 are hidden data buffers, last 5 are drawn lines
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

#include <Wininet.mqh>

// Inputs
input string ServerUrl = "http://127.0.0.1:5000/darvas"; // server endpoint
input int    RequestTimeoutMs = 5000;
input int    RequestIntervalSec = 60;   // polling interval
input color  BoxColor = clrDodgerBlue;
input color  WaveColor = clrYellow;
input color  FibColor = clrOrange;
input int    BoxTransparency = 80;      // not used for rectangle fill in MQL5

// Max counts (indicator input type)
input int MaxBoxes = 1000;
input int MaxNodes = 1000;
input int MaxFibs  = 1000;

// Buffers (15)
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
double bufWave1[];  // DRAW_LINE
double bufWave2[];  // DRAW_LINE
double bufWave3[];  // DRAW_LINE
double bufWave4[];  // DRAW_LINE
double bufWave5[];  // DRAW_LINE

// Internal state
datetime last_request_time = 0;

// Buffer indices (0-based)
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

int OnInit()
{
  // Bind buffers
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

  // Style the wave lines
  SetIndexStyle(BI_WAVE1, DRAW_LINE, STYLE_SOLID, 2, clrAqua);
  SetIndexStyle(BI_WAVE2, DRAW_LINE, STYLE_SOLID, 2, clrLime);
  SetIndexStyle(BI_WAVE3, DRAW_LINE, STYLE_SOLID, 2, clrYellow);
  SetIndexStyle(BI_WAVE4, DRAW_LINE, STYLE_SOLID, 2, clrOrange);
  SetIndexStyle(BI_WAVE5, DRAW_LINE, STYLE_SOLID, 2, clrMagenta);

  // Initialize buffers to EMPTY_VALUE
  ClearAllBuffers();

  // Setup polling timer
  EventSetTimer(RequestIntervalSec);
  PrintFormat("DarvasElliottPlot initialized. ServerUrl=%s MaxBoxes=%d MaxNodes=%d MaxFibs=%d", ServerUrl, MaxBoxes, MaxNodes, MaxFibs);
  return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
  EventKillTimer();
  // Keep chart objects by default; remove them if you want:
  // DeleteDarvObjects();
}

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
  // No per-bar calculations required; buffers serve as data channels.
  return(rates_total);
}

void OnTimer()
{
  if(TimeCurrent() - last_request_time < RequestIntervalSec)
     return;

  last_request_time = TimeCurrent();
  RequestAndRender();
}

void RequestAndRender()
{
  ResetLastError();
  string response;
  int res = WebRequest("GET", ServerUrl, "", NULL, 0, response, NULL, RequestTimeoutMs);
  if(res == -1)
  {
    int err = GetLastError();
    PrintFormat("DarvasElliottPlot: WebRequest failed. Error=%d. Ensure %s is allowed in Tools->Options->Expert Advisors -> Allow WebRequest for listed URL", err, ServerUrl);
    ResetLastError();
    return;
  }
  if(res >= 400)
  {
    PrintFormat("DarvasElliottPlot: HTTP %d response from server: %s", res, response);
    return;
  }

  ParseDarvasPayload(response);
}

// Clear all buffers (set to EMPTY_VALUE) up to Bars-1
void ClearAllBuffers()
{
  int bcount = Bars;
  if(bcount <= 0) return;
  for(int i = 0; i < bcount; ++i)
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

// Delete objects prefixed with DARV_
void DeleteDarvObjects()
{
  string prefix = "DARV_";
  int total = ObjectsTotal(0);
  for(int i = total - 1; i >= 0; --i)
  {
    string name = ObjectName(0, i);
    if(StringFind(name, prefix) == 0)
      ObjectDelete(0, name);
  }
}

void ParseDarvasPayload(const string payload)
{
  // Remove previously created DARV_ objects
  DeleteDarvObjects();

  // Clear buffers
  ClearAllBuffers();

  int bars = Bars;
  if(bars <= 1)
  {
    Print("DarvasElliottPlot: not enough bars to store buffers.");
    return;
  }

  int effMaxBoxes = MathMin(MaxBoxes, bars - 1);
  int effMaxNodes = MathMin(MaxNodes, bars - 1);
  int effMaxFibs  = MathMin(MaxFibs,  bars - 1);

  if(effMaxBoxes < MaxBoxes || effMaxNodes < MaxNodes || effMaxFibs < MaxFibs)
    PrintFormat("DarvasElliottPlot: Effective maxima limited by Bars=%d -> effMaxBoxes=%d effMaxNodes=%d effMaxFibs=%d",
                bars, effMaxBoxes, effMaxNodes, effMaxFibs);

  string lines[];
  int count = StringSplit(payload, '\n', lines, WHOLE_ARRAY);
  if(count == 0)
  {
    Print("DarvasElliottPlot: empty payload");
    return;
  }

  int i = 0;
  // Parse BOXES
  if(i < count && StringTrim(lines[i]) == "BOXES") i++;
  int box_idx = 0;
  while(i < count && StringTrim(lines[i]) != "ENDBOXES")
  {
    string line = StringTrim(lines[i++]);
    if(StringLen(line) == 0) continue;
    string parts[];
    int p = StringSplit(line, '|', parts, WHOLE_ARRAY);
    if(p >= 7)
    {
      string sdt = parts[0];
      string edt = parts[1];
      double top = StringToDouble(parts[2]);
      double bottom = StringToDouble(parts[3]);
      string trend = parts[4];
      int sidx = (int)StringToInteger(parts[5]);
      int eidx = (int)StringToInteger(parts[6]);

      datetime t1 = ParseDatetimeSafe(sdt);
      datetime t2 = ParseDatetimeSafe(edt);
      if(t1 == 0) t1 = Time[Bars-1];
      if(t2 == 0) t2 = Time[0];

      // Draw rectangle object
      string box_name = StringFormat("DARV_BOX_%d", box_idx);
      bool ok = ObjectCreate(0, box_name, OBJ_RECTANGLE, 0, t1, top, t2, bottom);
      if(ok)
      {
        ObjectSetInteger(0, box_name, OBJPROP_COLOR, BoxColor);
        ObjectSetInteger(0, box_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, box_name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, box_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, box_name, OBJPROP_SELECTABLE, false);
      }

      // Write into data buffers at index box_idx (if within effective maxima)
      if(box_idx < effMaxBoxes)
      {
        int idx = box_idx;
        if(idx < Bars) // safety
        {
          bufBoxTop[idx] = top;
          bufBoxBottom[idx] = bottom;
          bufBoxT1[idx] = (double)t1;
          bufBoxT2[idx] = (double)t2;
        }
      }
      ++box_idx;
    }
  }

  // Advance to WAVES
  while(i < count && StringTrim(lines[i]) != "WAVES") i++;
  if(i < count && StringTrim(lines[i]) == "WAVES") i++;

  // Parse WAVES
  int pattern_count = 0;
  int node_idx = 0;
  while(i < count && StringTrim(lines[i]) != "ENDWAVES")
  {
    string line = StringTrim(lines[i++]);
    if(StringLen(line) == 0) continue;
    string parts[];
    int p = StringSplit(line, '|', parts, WHOLE_ARRAY);
    if(p >= 7)
    {
      int pattern_idx = (int)StringToInteger(parts[0]);
      int node_i = (int)StringToInteger(parts[1]);
      int wave_number = (int)StringToInteger(parts[2]); // 1..5 expected
      string tstr = parts[3];
      double price = StringToDouble(parts[4]);
      int boxidx = (int)StringToInteger(parts[5]);
      string kind = parts[6];

      datetime tnode = ParseDatetimeSafe(tstr);
      if(tnode == 0) tnode = Time[0];

      // Create text and arrow objects
      string node_name = StringFormat("DARV_PAT%d_NODE%d", pattern_idx, node_i);
      ObjectCreate(0, node_name, OBJ_TEXT, 0, tnode, price);
      ObjectSetString(0, node_name, OBJPROP_TEXT, StringFormat("%d:%s", wave_number, kind));
      ObjectSetInteger(0, node_name, OBJPROP_COLOR, WaveColor);
      ObjectSetInteger(0, node_name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, node_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, node_name, OBJPROP_SELECTABLE, false);

      string arrow_name = StringFormat("DARV_PAT%d_NODE%d_ARROW", pattern_idx, node_i);
      ObjectCreate(0, arrow_name, OBJ_ARROW, 0, tnode, price);
      ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, WaveColor);
      ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, 233);

      // Store into sequential data buffers (entry index)
      if(node_idx < effMaxNodes)
      {
        int idx = node_idx;
        if(idx < Bars) // safety
        {
          bufNodePrice[idx] = price;
          bufNodeTime[idx] = (double)tnode;
          bufNodeBoxIdx[idx] = (double)boxidx;
        }
      }
      ++node_idx;
      if(pattern_idx + 1 > pattern_count) pattern_count = pattern_idx + 1;

      // Also put the node price into the appropriate wave-line buffer at the bar shift
      if(wave_number >= 1 && wave_number <= 5)
      {
        int shift = iBarShift(Symbol(), Period(), tnode, false); // find nearest bar
        if(shift >= 0 && shift < Bars)
        {
          switch(wave_number)
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

  // advance to FIBS
  while(i < count && StringTrim(lines[i]) != "FIBS") i++;
  if(i < count && StringTrim(lines[i]) == "FIBS") i++;

  // Parse FIBS
  int fib_idx = 0;
  while(i < count && StringTrim(lines[i]) != "ENDFIBS")
  {
    string line = StringTrim(lines[i++]);
    if(StringLen(line) == 0) continue;
    string parts[];
    int p = StringSplit(line, '|', parts, WHOLE_ARRAY);
    if(p >= 4)
    {
      int pattern_idx = (int)StringToInteger(parts[0]);
      int wave_ref = (int)StringToInteger(parts[1]);
      double level_pct = StringToDouble(parts[2]);
      double level_price = StringToDouble(parts[3]);

      string fib_name = StringFormat("DARV_PAT%d_FIB_%d", pattern_idx, fib_idx);
      ObjectCreate(0, fib_name, OBJ_HLINE, 0, TimeCurrent(), level_price);
      ObjectSetInteger(0, fib_name, OBJPROP_COLOR, FibColor);
      ObjectSetInteger(0, fib_name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, fib_name, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, fib_name, OBJPROP_TEXT, StringFormat("P%d R%d %.3f", pattern_idx, wave_ref, level_pct));

      if(fib_idx < effMaxFibs)
      {
        int idx = fib_idx;
        if(idx < Bars) // safety
        {
          bufFibPrice[idx] = level_price;
          bufFibPct[idx] = level_pct;
          bufFibPatternIdx[idx] = (double)pattern_idx;
        }
      }
      ++fib_idx;
    }
  }

  PrintFormat("DarvasElliottPlot: parsed %d boxes, %d nodes, %d fib entries (wave lines plotted)", box_idx, node_idx, fib_idx);
}

// Safe parse of datetime string in format "YYYY.MM.DD HH:MM" or empty
datetime ParseDatetimeSafe(const string s)
{
  string str = StringTrim(s);
  if(StringLen(str) == 0) return 0;
  datetime dt = StringToTime(str);
  if(dt == 0)
  {
    string tmp = StringReplace(str, ".", "-");
    dt = StringToTime(tmp);
  }
  return dt;
}
