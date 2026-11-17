//+------------------------------------------------------------------+
//| RSIP.mq5                                                         |
//| RSI Oversold Strategy — PRD v2.0 (same as RSI_Oversold_EA)        |
//| Compile this file from MQL5\Experts\ — Modules live in           |
//| MQL5\Experts\RSI_Oversold_EA\Modules\                             |
//+------------------------------------------------------------------+
#property copyright "RSI Oversold EA"
#property version   "1.03"

#include <Trade\Trade.mqh>

enum ENUM_TP_RULE
  {
   TP_RULE_FIXED_RR = 0,
   TP_RULE_OPEN = 1
  };
#include "RSI_Oversold_EA/Modules/Common.mqh"
#include "RSI_Oversold_EA/Modules/RSI_Engine.mqh"
#include "RSI_Oversold_EA/Modules/SweepDetector.mqh"
#include "RSI_Oversold_EA/Modules/SessionManager.mqh"
#include "RSI_Oversold_EA/Modules/PsychLevels.mqh"
#include "RSI_Oversold_EA/Modules/ProtectedLows.mqh"
#include "RSI_Oversold_EA/Modules/SetupScorer.mqh"
#include "RSI_Oversold_EA/Modules/RiskManager.mqh"
#include "RSI_Oversold_EA/Modules/TradeManager.mqh"
#include "RSI_Oversold_EA/Modules/AlertSystem.mqh"
#include "RSI_Oversold_EA/Modules/WeeklyReport.mqh"
#include "RSI_Oversold_EA/Modules/TradeLogger.mqh"

#define OBJ_PREFIX    "RSI_OS_"
#define OBJ_UI_PREFIX "RSI_OS_UI_"

//--- Dark Luxury design system (BGR hex / C'R,G,B')
#define UI_BG_MAIN      C'10,10,10'       // #0A0A0A Deep Black
#define UI_BG_CARD      C'17,17,17'       // #111111 Charcoal
#define UI_GOLD         C'212,175,55'     // #D4AF37 Signature Gold (BGR 0x37AFD4)
#define UI_TEXT         C'245,245,245'    // #F5F5F5 Ice White
#define UI_TEXT_MUTED   C'160,160,160'    // #A0A0A0 Muted Silver
#define UI_MINT         C'0,230,118'      // #00E676 Neon Mint
#define UI_CRIMSON      C'255,59,48'      // #FF3B30 Crimson Red
#define UI_CYAN         C'0,188,212'      // #00BCD4 RSI Hero
#define UI_FONT         "Trebuchet MS"    // Space Grotesk / Futura fallback
#define UI_ICON_FONT    "Wingdings"

//--- inputs PRD §5
input string InpSectionGeneral = "=== General ==="; // ----
input bool   EnableTrading = false;
input bool   EnableAlerts = true;
input int    Magic = 20260101;
input string TradeComment = "RSI-OS-EA";

input string InpSectionRsi = "=== RSI ==="; // ----
input int    RSI_Period = 14;
input int    RSI_Oversold = 30;
input ENUM_TIMEFRAMES RSI_Timeframe = PERIOD_M5;

input string InpSectionSweep = "=== Sweep ==="; // ----
input int    Sweep_Lookback = 10;
input double Sweep_WickRatio = 1.5;

input string InpSectionSession = "=== Session (UTC) ==="; // ----
input bool   Session_FilterEnabled = true;
input int    London_Start = 8;
input int    London_End = 16;
input int    NY_Start = 13;
input int    NY_End = 22;

input string InpSectionPsych = "=== Psych Levels ==="; // ----
input bool   Psych_Enabled = true;
input int    Psych_Distance = 15;

input string InpSectionLows = "=== Protected Lows ==="; // ----
input int    Lows_Lookback = 20;
input int    Lows_Distance = 20;

input string InpSectionTrade = "=== Trade ==="; // ----
input int    SL_Pips = 150;
input double RR_Ratio = 3.0;
input int    MinHoldHours = 4;
input bool   TrailingStop_Enabled = true;
input int    TrailingStop_Pips = 50;
input string MinScore_AutoTrade = "A+";

input string InpSectionRisk = "=== Risk ==="; // ----
input bool   Risk_Use_Per_Setup = true;
input double Risk_Percent = 1.0;
input double Risk_Pct_A_Plus = 1.0;
input double Risk_Pct_A = 0.75;
input double Risk_Pct_B = 0.0;
input double Risk_Pct_C = 0.0;
input double MaxDailyLoss_Percent = 3.0;
input double MinBalance = 1000.0;
input int    MaxConcurrentTrades = 1;

input string InpSectionPos = "=== Position management ==="; // ----
input bool   Pyramid_Enabled = false;
input int    Pyramid_MaxAdds = 2;
input int    Pyramid_MinBarsBetween = 2;
input double Pyramid_MinProfitR = 0.5;
input bool   Breakeven_Enabled = true;
input int    Breakeven_TriggerPips = 100;
input int    Breakeven_OffsetPips = 10;
input bool   Breakeven_RespectMinHold = true;
input bool   Trailing_OnlyAfterBreakeven = true;
input ENUM_TP_RULE TP_Rule = TP_RULE_FIXED_RR;

input string InpSectionAlerts = "=== Alerts ==="; // ----
input bool   Alert_RSI = true;
input bool   Alert_Setup = true;
input bool   Alert_APlus = true;
input bool   Alert_Push = true;
input bool   Alert_Email = false;

input string InpSectionReport = "=== Reporting ==="; // ----
input bool   WeeklyReport_Enabled = true;
input bool   LogTrades_CSV = true;
input string LogPath = "RSI_OS_Trades.csv";

input string InpSectionUi = "=== Dashboard ==="; // ----
input bool   Dashboard_StartCollapsed = false;
input int    HistSignal_Bars = 250; // historical markers lookback (bars)

//--- state
int            g_rsi_handle = INVALID_HANDLE;
datetime       g_last_bar_time = 0;
bool           g_prev_enable_trading = false;
double         g_day_start_balance = 0.0;
int            g_day_key = -1;
int            g_auto_min_rank = 3;
SWeekStats     g_week;
datetime       g_last_week_check = 0;
int            g_week_report_daykey = -1;
bool           g_dashboard_collapsed = false;
int            g_ui_dx = 10;   // dashboard left (drag)
int            g_ui_dy = 34;   // dashboard top (drag)
int            g_sig_cnt_ap = 0; // markers painted on chart (history + live)
int            g_sig_cnt_a  = 0;
int            g_sig_cnt_b  = 0;
int            g_sig_cnt_c  = 0;

struct SUiDashCache
  {
   bool              valid;
   bool              trading_on;
   SRsiState         rsi_live;
   SSetupSnapshot    snap;
   bool              disp_c1;
   bool              disp_c2;
   bool              disp_c3;
   bool              disp_c4;
   bool              disp_c5;
   double            psych_level;
   double            psych_dist;
   double            sup_level;
   double            sup_dist;
   string            session_name;
  };

SUiDashCache g_ui_cache;

struct SOpenContext
  {
   long              position_id;
   datetime          open_time;
   double            entry;
   double            lots;
   double            sl;
   double            tp;
   int               sl_pips;
   SSetupSnapshot    snap;
   double            rsi_val;
   string            session_name;
  };

SOpenContext g_open_cache[32];
int g_open_cache_n = 0;

static int      s_pyramid_adds = 0;
static datetime s_pyramid_anchor = 0;

void OpenCacheUpdateLots(const long position_id, const double lots)
  {
   for(int i = 0; i < g_open_cache_n; i++)
     {
      if(g_open_cache[i].position_id == position_id)
        {
         g_open_cache[i].lots = lots;
         return;
        }
     }
  }

/**
 * Single calendar-day id (portable — MqlDateTime has no day_of_year on all builds).
 */
int CalendarDayKey(const MqlDateTime &dt)
  {
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

//+------------------------------------------------------------------+
int BarUtcHour(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   const datetime bt = iTime(sym, tf, shift);
   const long skew = (long)(TimeGMT() - TimeCurrent());
   const datetime utc = (datetime)((long)bt + skew);
   MqlDateTime m;
   TimeToStruct(utc, m);
   return (int)m.hour;
  }

//+------------------------------------------------------------------+
void OpenCacheAdd(const SOpenContext &ctx)
  {
   if(g_open_cache_n >= 32)
      return;
   g_open_cache[g_open_cache_n++] = ctx;
  }

bool OpenCacheTake(const long position_id, SOpenContext &out)
  {
   for(int i = 0; i < g_open_cache_n; i++)
     {
      if(g_open_cache[i].position_id == position_id)
        {
         out = g_open_cache[i];
         for(int j = i; j < g_open_cache_n - 1; j++)
            g_open_cache[j] = g_open_cache[j + 1];
         g_open_cache_n--;
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Dark Luxury UI helpers — reuse named objects (no tick leak)      |
//+------------------------------------------------------------------+
void UiClearByPrefix(const string pfx)
  {
   const int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      const string nm = ObjectName(0, i, 0, -1);
      if(StringFind(nm, pfx) == 0)
         ObjectDelete(0, nm);
     }
  }

void UiClear()
  {
   UiClearByPrefix(OBJ_UI_PREFIX);
   UiClearByPrefix(OBJ_PREFIX);
  }

/**
 * Wipe legacy dashboard names left from earlier UI versions (overlap source).
 */
void UiPurgeLegacyDashboard()
  {
   UiClearByPrefix(OBJ_UI_PREFIX);
   // old single-prefix dashboard objects still sitting on chart
   string legacy[] =
     {
      "card_main","card_score","dash_toggle","dot_live",
      "h1","h2","h2_lbl","h2_meta","mode",
      "gauge_bg","gauge_fill","gauge_min","gauge_mid","gauge_max",
      "div1","div2","div3","div4","div_h_grid","div_v",
      "i1","i2","i3","i4","i5","t1","t2","t3","t4","t5","v1","v2","v3","v4","v5",
      "r1","r2","r3","r4","r5","r6","r7",
      "sc","sc_lbl","sc_meta","sc_sig","wk",
      "m_sl","m_tp","m_rr","leg_ap","leg_a","leg_b","leg_c","sess"
     };
   for(int i = 0; i < ArraySize(legacy); i++)
      ObjectDelete(0, OBJ_PREFIX + legacy[i]);
  }

void UiSetHidden(const string name, const bool hidden, const string pfx = OBJ_UI_PREFIX)
  {
   const string n = pfx + name;
   if(ObjectFind(0, n) >= 0)
      ObjectSetInteger(0, n, OBJPROP_TIMEFRAMES, hidden ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS);
  }

/**
 * Delete dashboard widgets but keep the SHOW/HIDE button (avoids TIMEFRAMES unhide bug).
 */
void UiClearDashboardExceptToggle()
  {
   const int total = ObjectsTotal(0, 0, -1);
   const string keep = OBJ_UI_PREFIX + "dash_toggle";
   for(int i = total - 1; i >= 0; i--)
     {
      const string nm = ObjectName(0, i, 0, -1);
      if(StringFind(nm, OBJ_UI_PREFIX) != 0)
         continue;
      if(nm == keep)
         continue;
      ObjectDelete(0, nm);
     }
  }

void UiLabelSetHidden(const string name, const bool hidden)
  {
   UiSetHidden(name, hidden, OBJ_UI_PREFIX);
  }

/**
 * Card / panel background (OBJ_RECTANGLE_LABEL).
 */
void UiCard(const string name, const int corner, const int x, const int y,
            const int w, const int h, const color bg, const color border,
            const int border_width = 1, const string pfx = OBJ_UI_PREFIX)
  {
   const string n = pfx + name;
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, n, OBJPROP_COLOR, border);
   ObjectSetInteger(0, n, OBJPROP_WIDTH, border_width);
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, 0);
  }

void UiLabel(const string name, const int corner, const int x, const int y,
             const string text, const color clr, const int size = 9,
             const string font = "Trebuchet MS", const string pfx = OBJ_UI_PREFIX)
  {
   const string n = pfx + name;
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetString(0, n, OBJPROP_FONT, font);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, 10);
   ObjectSetInteger(0, n, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  }

/**
 * Compact SL/TP tag anchored to chart time/price (near HLine).
 */
void UiPriceTag(const string name, const datetime t, const double price,
                const string text, const color clr, const int size = 8)
  {
   const string n = OBJ_PREFIX + name;
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_TEXT, 0, t, price);
   else
      ObjectMove(0, n, 0, t, price);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetString(0, n, OBJPROP_FONT, UI_FONT);
   ObjectSetInteger(0, n, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
  }

/**
 * Collapsible dashboard toggle — compact gold control.
 */
void UiDashboardToggleEnsure()
  {
   const string n = OBJ_UI_PREFIX + "dash_toggle";
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, n, OBJPROP_FONT, UI_FONT);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, n, OBJPROP_ZORDER, 100);
     }
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, g_ui_dx);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, MathMax(8, g_ui_dy - 26));
   ObjectSetString(0, n, OBJPROP_TEXT, g_dashboard_collapsed ? "SHOW" : "HIDE");
   ObjectSetInteger(0, n, OBJPROP_XSIZE, 56);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, 18);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, UI_BG_CARD);
   ObjectSetInteger(0, n, OBJPROP_COLOR, UI_GOLD);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, UI_GOLD);
  }

void UiTriangle(const string name, const datetime t, const double price,
                const color clr, const int width)
  {
   const string n = OBJ_PREFIX + name;
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_ARROW_UP, 0, t, price);
   else
      ObjectMove(0, n, 0, t, price);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, n, OBJPROP_ANCHOR, ANCHOR_TOP);
  }

void UiHLine(const string name, const double price, const color clr,
             const ENUM_LINE_STYLE st, const int width = 1)
  {
   const string n = OBJ_PREFIX + name;
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble(0, n, OBJPROP_PRICE, price);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_STYLE, st);
   ObjectSetInteger(0, n, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, n, OBJPROP_BACK, true);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
  }

/**
 * Status glyph: Wingdings check / cross.
 * Absent criteria stay muted silver (mockup), not crimson.
 */
string UiStatusGlyph(const bool ok)
  {
   return ok ? CharToString((uchar)252) : CharToString((uchar)251);
  }

color UiStatusGlyphColor(const bool ok, const bool accent_gold = false)
  {
   if(!ok)
      return UI_TEXT_MUTED;
   return accent_gold ? UI_GOLD : UI_MINT;
  }

color UiScoreColor(const ESetupScore score)
  {
   if(score == SCORE_A_PLUS)
      return UI_GOLD;
   if(score == SCORE_A)
      return UI_MINT;
   if(score == SCORE_B)
      return UI_CYAN;
   if(score == SCORE_C)
      return UI_TEXT_MUTED;
   return UI_TEXT_MUTED;
  }

string UiTimeframeShort(const ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      default:         return "M5";
     }
  }

string UiUpper(string s)
  {
   StringToUpper(s);
   return s;
  }

void UiDivider(const string name, const int corner, const int x, const int y, const int w)
  {
   UiCard(name, corner, x, y, w, 1, C'42,42,42', C'42,42,42', 1);
  }

/**
 * One criteria cell: glyph + title + value.
 */
void UiCriterionCell(const string id, const int corner,
                     const int x, const int y,
                     const bool ok, const bool accent_gold,
                     const string title, const string value, const color value_clr)
  {
   UiLabel("i" + id, corner, x, y + 2,
           UiStatusGlyph(ok), UiStatusGlyphColor(ok, accent_gold), 12, UI_ICON_FONT);
   UiLabel("t" + id, corner, x + 18, y,
           title, ok ? UI_TEXT : UI_TEXT_MUTED, 8, UI_FONT);
   UiLabel("v" + id, corner, x + 18, y + 14,
           value, value_clr, 9, UI_FONT);
  }

void UiDashHideAll(const bool hide)
  {
   // Prefer hard clear over OBJPROP_TIMEFRAMES (labels can fail to resurface).
   if(hide)
      UiClearDashboardExceptToggle();
  }

/**
 * Right-edge price pill (mockup SL/TP/PSYCH tags).
 */
void UiRightPricePill(const string name, const double price,
                      const string text, const color bg, const color fg)
  {
   int x = 0, y = 0;
   const datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(!ChartTimePriceToXY(0, 0, t, price, x, y))
      return;
   const int chart_w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   const int box_w = 96;
   const int box_h = 18;
   const int bx = MathMax(8, chart_w - box_w - 58);
   const int by = y - box_h / 2;
   UiCard(name + "_bg", CORNER_LEFT_UPPER, bx, by, box_w, box_h, bg, bg, 1, OBJ_PREFIX);
   UiLabel(name, CORNER_LEFT_UPPER, bx + 6, by + 2, text, fg, 8, UI_FONT, OBJ_PREFIX);
  }

void UiPaintSignalTriangle(const datetime t, const double price, const ESetupScore score)
  {
   if(score < SCORE_B || score == SCORE_NONE)
      return;
   int w = 2;
   color tri_clr = UI_CYAN;
   if(score == SCORE_A_PLUS)
     {
      w = 5;
      tri_clr = UI_GOLD;
     }
   else if(score == SCORE_A)
     {
      w = 3;
      tri_clr = UI_MINT;
     }
   else if(score == SCORE_B)
     {
      w = 2;
      tri_clr = UI_CRIMSON;
     }
   const string sig_id = "s" + DoubleToString((double)t, 0);
   UiTriangle(StringFormat("tri%s", sig_id), t, price, tri_clr, w);
  }

void UiCountSignalGrade(const ESetupScore score)
  {
   if(score == SCORE_A_PLUS)
      g_sig_cnt_ap++;
   else if(score == SCORE_A)
      g_sig_cnt_a++;
   else if(score == SCORE_B)
      g_sig_cnt_b++;
   else if(score == SCORE_C)
      g_sig_cnt_c++;
  }

/**
 * Evaluate setup at a closed-bar shift (1 = last closed).
 */
bool EvaluateSetupAtShift(const int shift, const double pip,
                          SSetupSnapshot &snap,
                          bool &out_c1, bool &out_c2, bool &out_c3, bool &out_c4, bool &out_c5,
                          double &out_psych, double &out_psych_dist,
                          double &out_sup, double &out_sup_dist,
                          string &out_session_name)
  {
   out_c1 = out_c2 = out_c3 = out_c4 = out_c5 = false;
   out_psych = out_sup = 0.0;
   out_psych_dist = out_sup_dist = 0.0;
   out_session_name = "";
   ScoreClassify(false, false, false, false, false, snap);

   if(shift < 1 || pip <= 0.0)
      return false;

   SRsiState rsi;
   RsiEvaluate(g_rsi_handle, RSI_Oversold, rsi, shift);
   out_c1 = rsi.valid && rsi.oversold;

   const int hour_utc = BarUtcHour(_Symbol, RSI_Timeframe, shift);
   ESessionLabel lab;
   SessionGetLabel(hour_utc, London_Start, London_End, NY_Start, NY_End, lab, out_session_name);
   const bool london_ny = SessionIsLondonOrNY(hour_utc, London_Start, London_End, NY_Start, NY_End);
   out_c3 = (!Session_FilterEnabled) ? true : london_ny;
   const bool session_gate = (!Session_FilterEnabled || london_ny);

   if(!session_gate || !out_c1)
      return false;

   out_c2 = SweepDetect(_Symbol, RSI_Timeframe, shift, Sweep_Lookback, Sweep_WickRatio, pip);
   const double low_s = iLow(_Symbol, RSI_Timeframe, shift);
   out_c4 = PsychCriterion(Psych_Enabled, _Symbol, low_s, Psych_Distance, pip, out_psych, out_psych_dist);
   out_c5 = ProtectedLowCriterionAt(_Symbol, RSI_Timeframe, shift, Lows_Lookback, Lows_Distance,
                                    pip, out_sup, out_sup_dist);
   ScoreClassify(true, out_c2, out_c3, out_c4, out_c5, snap);
   return true;
  }

/**
 * Paint A+/A/B triangles for recent closed bars (historical visibility).
 */
void UiPaintHistoricalSignals(const double pip)
  {
   g_sig_cnt_ap = g_sig_cnt_a = g_sig_cnt_b = g_sig_cnt_c = 0;
   if(HistSignal_Bars < 1 || pip <= 0.0)
      return;
   const int max_bars = Bars(_Symbol, RSI_Timeframe) - 5;
   if(max_bars < 1)
      return;
   const int bars = (int)MathMin((double)HistSignal_Bars, (double)max_bars);
   for(int shift = 1; shift <= bars; shift++)
     {
      SSetupSnapshot snap;
      bool c1, c2, c3, c4, c5;
      double psych, psych_d, support, support_d;
      string sess;
      EvaluateSetupAtShift(shift, pip, snap, c1, c2, c3, c4, c5,
                           psych, psych_d, support, support_d, sess);
      if(snap.score == SCORE_NONE)
         continue;
      UiCountSignalGrade(snap.score);
      if(snap.score < SCORE_B)
         continue;
      const datetime bt = iTime(_Symbol, RSI_Timeframe, shift);
      const double lowb = iLow(_Symbol, RSI_Timeframe, shift);
      UiPaintSignalTriangle(bt, lowb, snap.score);
     }
  }

/**
 * Mockup-faithful Dark Luxury dashboard.
 * Display uses live RSI (shift 0); signal logic stays on closed-bar RSI.
 */
void UiDashboardRender(const bool trading_on,
                       const SRsiState &rsi_live,
                       const SSetupSnapshot &snap,
                       const bool disp_c1, const bool disp_c2, const bool disp_c3,
                       const bool disp_c4, const bool disp_c5,
                       const double psych_level, const double psych_dist,
                       const double sup_level, const double sup_dist,
                       const string session_name,
                       const int min_hold_hours,
                       const SWeekStats &week)
  {
   UiDashboardToggleEnsure();
   if(g_dashboard_collapsed)
     {
      UiClearDashboardExceptToggle();
      ChartRedraw(0);
      return;
     }

   const int corner = CORNER_LEFT_UPPER;
   const int dx = g_ui_dx;
   const int card_y = g_ui_dy;
   const int card_w = 300;
   const int pad = 16;
   const int content_w = card_w - pad * 2;
   const int col_w = content_w / 2;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   const int y_title   = card_y + 14;
   const int y_mode    = card_y + 34;
   const int y_hero    = card_y + 58;
   const int y_gauge   = card_y + 102;
   const int y_grid    = card_y + 138;
   const int cell_h    = 48;
   const int y_prot    = y_grid + cell_h * 2 + 10;
   const int y_badge   = y_prot + 34;
   const int badge_h   = 100;
   const int y_metrics = y_badge + badge_h + 16;
   const int y_legend  = y_metrics + 28;
   const int y_sess    = y_legend + 22;
   const int card_h    = (y_sess + 28) - card_y;

   const int criteria_live =
      (disp_c1 ? 1 : 0) + (disp_c2 ? 1 : 0) + (disp_c3 ? 1 : 0) +
      (disp_c4 ? 1 : 0) + (disp_c5 ? 1 : 0);

   UiCard("card_main", corner, dx, card_y, card_w, card_h, UI_BG_MAIN, UI_GOLD, 1);
   ObjectSetInteger(0, OBJ_UI_PREFIX + "card_main", OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, OBJ_UI_PREFIX + "card_main", OBJPROP_SELECTED, false);
   ObjectSetInteger(0, OBJ_UI_PREFIX + "card_main", OBJPROP_ZORDER, 1);
   ObjectSetString(0, OBJ_UI_PREFIX + "card_main", OBJPROP_TOOLTIP,
                   StringFormat("Drag panel to move | Psych %.5g (%.1f) | Low %.5g (%.1f)",
                                psych_level, psych_dist, sup_level, sup_dist));

   UiLabel("h1", corner, dx + pad, y_title,
           "RSI OVERSOLD STRATEGY", UI_TEXT, 11, UI_FONT);
   UiLabel("dot_live", corner, dx + card_w - pad - 12, y_title + 2,
           CharToString((uchar)108), UI_GOLD, 11, UI_ICON_FONT);
   if(trading_on)
      UiLabel("mode", corner, dx + pad, y_mode,
              "AUTO-TRADING ACTIVE", UI_MINT, 8, UI_FONT);
   else
      UiLabel("mode", corner, dx + pad, y_mode,
              "ALERT MODE — TRADING OFF", UI_CRIMSON, 8, UI_FONT);

   const double rsi_val = rsi_live.valid ? rsi_live.value : 0.0;
   color rsi_clr = UI_TEXT_MUTED;
   if(rsi_live.valid)
     {
      if(rsi_live.value <= (double)RSI_Oversold)
         rsi_clr = UI_CYAN;          // oversold — mockup hero cyan
      else if(rsi_live.value <= 40.0)
         rsi_clr = UI_GOLD;          // approaching oversold
      else if(rsi_live.value >= 70.0)
         rsi_clr = UI_CRIMSON;       // overbought warning
      else
         rsi_clr = UI_TEXT;          // neutral
     }

   UiLabel("h2", corner, dx + pad, y_hero,
           rsi_live.valid ? StringFormat("%.1f", rsi_val) : "-",
           rsi_clr, 26, UI_FONT);
   UiLabel("h2_meta", corner, dx + pad + 100, y_hero + 12,
           StringFormat("RSI %d | %s", RSI_Period, UiTimeframeShort(RSI_Timeframe)),
           UI_TEXT_MUTED, 8, UI_FONT);

   const int gauge_h = 6;
   UiCard("gauge_bg", corner, dx + pad, y_gauge, content_w, gauge_h, C'28,28,28', C'28,28,28', 1);
   int fill_w = 1;
   if(rsi_live.valid)
     {
      fill_w = (int)MathRound(content_w * MathMin(100.0, MathMax(0.0, rsi_val)) / 100.0);
      if(fill_w < 2)
         fill_w = 2;
     }
   UiCard("gauge_fill", corner, dx + pad, y_gauge, fill_w, gauge_h, UI_CYAN, UI_CYAN, 1);
   UiLabel("gauge_min", corner, dx + pad, y_gauge + 10, "0", UI_TEXT_MUTED, 7, UI_FONT);
   UiLabel("gauge_mid", corner, dx + pad + content_w / 2 - 12, y_gauge + 10,
           rsi_live.valid ? StringFormat("%.1f", rsi_val) : "-", UI_CYAN, 7, UI_FONT);
   UiLabel("gauge_max", corner, dx + pad + content_w - 20, y_gauge + 10, "100", UI_TEXT_MUTED, 7, UI_FONT);

   UiDivider("div1", corner, dx + pad, y_grid - 10, content_w);

   // Dynamic criterion colors (independent of setup gate — reflects live status)
   UiCriterionCell("1", corner, dx + pad, y_grid, disp_c1, false, "RSI",
                   rsi_live.valid ? StringFormat("%.1f", rsi_val) : "-",
                   disp_c1 ? UI_MINT : UI_TEXT_MUTED);
   UiCriterionCell("2", corner, dx + pad + col_w, y_grid, disp_c2, false, "SWEEP",
                   disp_c2 ? "DETECTED" : "absent",
                   disp_c2 ? UI_MINT : UI_TEXT_MUTED);
   UiCriterionCell("3", corner, dx + pad, y_grid + cell_h, disp_c3, false, "SESSION",
                   UiUpper(session_name),
                   disp_c3 ? UI_MINT : UI_TEXT_MUTED);
   UiCriterionCell("4", corner, dx + pad + col_w, y_grid + cell_h, disp_c4, true, "PSYCH",
                   disp_c4 ? DoubleToString(psych_level, digits) : "absent",
                   disp_c4 ? UI_GOLD : UI_TEXT_MUTED);

   UiDivider("div_h_grid", corner, dx + pad, y_grid + cell_h - 4, content_w);
   UiCard("div_v", corner, dx + pad + col_w - 1, y_grid + 4, 1, cell_h * 2 - 12,
          C'42,42,42', C'42,42,42', 1);

   UiLabel("i5", corner, dx + pad, y_prot + 2,
           UiStatusGlyph(disp_c5), UiStatusGlyphColor(disp_c5), 12, UI_ICON_FONT);
   UiLabel("t5", corner, dx + pad + 18, y_prot, "PROT.LOW",
           disp_c5 ? UI_TEXT : UI_TEXT_MUTED, 8, UI_FONT);
   UiLabel("v5", corner, dx + pad + 100, y_prot,
           disp_c5 ? "OK" : "absent", disp_c5 ? UI_MINT : UI_TEXT_MUTED, 9, UI_FONT);

   UiDivider("div2", corner, dx + pad, y_badge - 10, content_w);

   const color sc_clr = UiScoreColor(snap.score);
   const bool signal_on = (snap.score == SCORE_A || snap.score == SCORE_A_PLUS);
   const color badge_border = (snap.score == SCORE_A_PLUS) ? UI_GOLD
                             : (signal_on ? UI_MINT : C'60,60,60');
   UiCard("card_score", corner, dx + pad, y_badge, content_w, badge_h,
          UI_BG_CARD, badge_border, (snap.score == SCORE_A_PLUS) ? 2 : 1);

   string grade = snap.score_label;
   if(snap.score == SCORE_NONE || grade == "No Signal" || grade == "-")
      grade = "-";

   UiLabel("sc", corner, dx + pad + 18, y_badge + 8, grade, sc_clr, 34, UI_FONT);
   UiLabel("sc_meta", corner, dx + pad + 18, y_badge + 52,
           StringFormat("%d / 5 criteria", criteria_live), UI_TEXT, 9, UI_FONT);
   if(signal_on)
      UiLabel("sc_sig", corner, dx + pad + 18, y_badge + 72,
              "SIGNAL DETECTED", UI_MINT, 11, UI_FONT);
   else if(snap.score == SCORE_B)
      UiLabel("sc_sig", corner, dx + pad + 18, y_badge + 72,
              "WATCHLIST", UI_GOLD, 11, UI_FONT);
   else
      UiLabel("sc_sig", corner, dx + pad + 18, y_badge + 72,
              "NO SIGNAL", UI_TEXT_MUTED, 11, UI_FONT);

   UiDivider("div3", corner, dx + pad, y_metrics - 10, content_w);

   const int tp_pips = (int)MathRound(SL_Pips * RR_Ratio);
   UiLabel("m_sl", corner, dx + pad, y_metrics,
           StringFormat("SL: %d pips", SL_Pips), UI_CRIMSON, 8, UI_FONT);
   UiLabel("m_tp", corner, dx + pad + 100, y_metrics,
           StringFormat("TP: %d pips", tp_pips), UI_MINT, 8, UI_FONT);
   UiLabel("m_rr", corner, dx + pad + 200, y_metrics,
           StringFormat("RR: 1:%.0f", RR_Ratio), UI_TEXT, 8, UI_FONT);

   UiDivider("div4", corner, dx + pad, y_legend - 10, content_w);

   // Chart marker counts (history scan + live bars) — matches triangles on chart
   UiLabel("leg_ap", corner, dx + pad, y_legend,
           StringFormat("• A+: %d", g_sig_cnt_ap), UI_GOLD, 8, UI_FONT);
   UiLabel("leg_a", corner, dx + pad + 72, y_legend,
           StringFormat("• A: %d", g_sig_cnt_a), UI_MINT, 8, UI_FONT);
   UiLabel("leg_b", corner, dx + pad + 130, y_legend,
           StringFormat("• B: %d", g_sig_cnt_b), UI_CRIMSON, 8, UI_FONT);
   UiLabel("leg_c", corner, dx + pad + 184, y_legend,
           StringFormat("• C: %d", g_sig_cnt_c), UI_TEXT_MUTED, 8, UI_FONT);
   // week param retained for API compat; legend uses chart marker counts

   UiLabel("sess", corner, dx + pad, y_sess,
           UiUpper(session_name) + " SESSION",
           disp_c3 ? UI_MINT : UI_TEXT_MUTED, 9, UI_FONT);

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   g_rsi_handle = RsiCreateHandle(_Symbol, RSI_Timeframe, RSI_Period);
   if(g_rsi_handle == INVALID_HANDLE)
     {
      Print("[RSI-OS-EA] iRSI failed");
      return INIT_FAILED;
     }

   string ms = MinScore_AutoTrade;
   StringTrimLeft(ms);
   StringTrimRight(ms);
   if(ms == "A+")
      g_auto_min_rank = 4;
   else if(ms == "A")
      g_auto_min_rank = 3;
   else if(ms == "B")
      g_auto_min_rank = 2;
   else if(ms == "C")
      g_auto_min_rank = 1;
   else
     {
      Print("[RSI-OS-EA] MinScore_AutoTrade must be A+, A, B or C — got: ", MinScore_AutoTrade);
      return INIT_PARAMETERS_INCORRECT;
     }

   g_prev_enable_trading = EnableTrading;
   Print("[RSI-OS-EA] EnableTrading=", (EnableTrading ? "TRUE" : "FALSE"), " at ", TimeToString(TimeGMT(), TIME_DATE | TIME_SECONDS), " GMT");

   WeeklyReset(g_week, TimeGMT());
   g_last_week_check = TimeGMT();
   g_day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   MqlDateTime g;
   TimeToStruct(TimeTradeServer(), g);
   g_day_key = CalendarDayKey(g);

   g_dashboard_collapsed = Dashboard_StartCollapsed;
   g_ui_cache.valid = false;
   g_ui_dx = 10;
   g_ui_dy = 34;
   UiPurgeLegacyDashboard();

   const double pip_init = PipSize(_Symbol);
   if(pip_init > 0.0)
      UiPaintHistoricalSignals(pip_init);

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_rsi_handle != INVALID_HANDLE)
      IndicatorRelease(g_rsi_handle);
   UiClear();
  }

//+------------------------------------------------------------------+
void EnsureDayStartBalance()
  {
   MqlDateTime g;
   TimeToStruct(TimeTradeServer(), g);
   const int dk = CalendarDayKey(g);
   if(dk != g_day_key)
     {
      g_day_key = dk;
      g_day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
     }
  }

bool RiskDailyBlocked()
  {
   EnsureDayStartBalance();
   const double bal = g_day_start_balance;
   if(bal <= 0.0)
      return true;
   const double pnl = RiskDailyClosedPnl(Magic);
   const double limit = -bal * (MaxDailyLoss_Percent / 100.0);
   return (pnl <= limit);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   const double pip = PipSize(_Symbol);
   if(pip <= 0.0)
      return;

   EnsureDayStartBalance();

   if(WeeklyReport_Enabled)
     {
      MqlDateTime gw;
      TimeToStruct(TimeGMT(), gw);
      if(gw.day_of_week == 1 && gw.hour == 0 && gw.min == 0 &&
         g_week_report_daykey != CalendarDayKey(gw))
        {
         Print(WeeklyFormatReport(g_week, EnableTrading));
         WeeklyReset(g_week, TimeGMT());
         g_week_report_daykey = CalendarDayKey(gw);
        }
     }
   g_last_week_check = TimeGMT();

   if(EnableTrading != g_prev_enable_trading)
     {
      Print("[RSI-OS-EA] EnableTrading changed to: ", (EnableTrading ? "TRUE" : "FALSE"),
            " at ", TimeToString(TimeGMT(), TIME_DATE | TIME_SECONDS), " GMT");
      g_prev_enable_trading = EnableTrading;
     }

   const datetime bar0 = iTime(_Symbol, RSI_Timeframe, 0);
   const bool new_bar = (bar0 != g_last_bar_time);
   if(new_bar)
      g_last_bar_time = bar0;

   SRsiState rsi_st;
   RsiEvaluate(g_rsi_handle, RSI_Oversold, rsi_st, 1); // closed bar — signals / C1 logic

   SRsiState rsi_live;
   RsiEvaluate(g_rsi_handle, RSI_Oversold, rsi_live, 0); // forming bar — dashboard display


   const int hour_utc = BarUtcHour(_Symbol, RSI_Timeframe, 1);
   ESessionLabel lab;
   string session_name;
   SessionGetLabel(hour_utc, London_Start, London_End, NY_Start, NY_End, lab, session_name);
   const bool london_ny = SessionIsLondonOrNY(hour_utc, London_Start, London_End, NY_Start, NY_End);
   const bool session_gate = (!Session_FilterEnabled || london_ny);

   // Live clock session for dashboard colours (not gated on closed-bar / RSI)
   ESessionLabel lab_now;
   string session_name_live;
   const int hour_now = SessionUtcHour(TimeGMT());
   SessionGetLabel(hour_now, London_Start, London_End, NY_Start, NY_End, lab_now, session_name_live);
   const bool london_ny_now = SessionIsLondonOrNY(hour_now, London_Start, London_End, NY_Start, NY_End);

   //--- Display criteria: always evaluated (dynamic colours on dashboard)
   double psych_level = 0.0, psych_dist = 0.0;
   double sup_level = 0.0, sup_dist = 0.0;
   const double low1 = iLow(_Symbol, RSI_Timeframe, 1);

   const bool disp_c1 = rsi_live.valid && (rsi_live.value <= (double)RSI_Oversold);
   const bool disp_c2 = SweepDetect(_Symbol, RSI_Timeframe, 1, Sweep_Lookback, Sweep_WickRatio, pip);
   const bool disp_c3 = london_ny_now; // current GMT London/NY → mint
   const bool disp_c4 = PsychCriterion(Psych_Enabled, _Symbol, low1, Psych_Distance, pip, psych_level, psych_dist);
   const bool disp_c5 = ProtectedLowCriterion(_Symbol, RSI_Timeframe, Lows_Lookback, Lows_Distance, pip, sup_level, sup_dist);

   //--- Signal criteria (closed-bar C1 + session gate — trade logic unchanged)
   bool c1 = rsi_st.valid && rsi_st.oversold;
   bool c2 = false, c3 = false, c4 = false, c5 = false;
   if(session_gate && c1)
     {
      c2 = disp_c2;
      c3 = Session_FilterEnabled ? london_ny : true;
      c4 = disp_c4;
      c5 = disp_c5;
     }
   else if(!session_gate)
      c3 = false;

   SSetupSnapshot snap;
   if(!session_gate || !c1)
      ScoreClassify(false, false, false, false, false, snap);
   else
      ScoreClassify(true, c2, c3, c4, c5, snap);

   //--- cache UI state (toggle / drag can redraw without waiting for next tick)
   g_ui_cache.valid = true;
   g_ui_cache.trading_on = EnableTrading;
   g_ui_cache.rsi_live = rsi_live;
   g_ui_cache.snap = snap;
   g_ui_cache.disp_c1 = disp_c1;
   g_ui_cache.disp_c2 = disp_c2;
   g_ui_cache.disp_c3 = disp_c3;
   g_ui_cache.disp_c4 = disp_c4;
   g_ui_cache.disp_c5 = disp_c5;
   g_ui_cache.psych_level = psych_level;
   g_ui_cache.psych_dist = psych_dist;
   g_ui_cache.sup_level = sup_level;
   g_ui_cache.sup_dist = sup_dist;
   g_ui_cache.session_name = session_name_live;

   //--- Dark Luxury floating dashboard
   UiDashboardRender(EnableTrading, rsi_live, snap,
                     disp_c1, disp_c2, disp_c3, disp_c4, disp_c5,
                     psych_level, psych_dist, sup_level, sup_dist,
                     session_name_live, MinHoldHours, g_week);

   //--- live psych overlay (mockup)
   const int digits_ui = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(disp_c4 && psych_level > 0.0)
     {
      UiHLine("ov_psych", psych_level, UI_TEXT_MUTED, STYLE_DOT, 1);
      UiRightPricePill("ov_psych", psych_level,
                       StringFormat("PSYCH %s", DoubleToString(psych_level, digits_ui)),
                       C'70,70,70', UI_TEXT);
     }

   //--- manage open position: breakeven then trailing
   const ulong pos_ticket = TradeFindPositionTicket(_Symbol, Magic);
   if(pos_ticket == 0)
     {
      s_pyramid_adds = 0;
      s_pyramid_anchor = 0;
     }
   if(pos_ticket != 0 && PositionSelectByTicket(pos_ticket))
     {
      const datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      TradeApplyBreakeven(_Symbol, Magic, pip, Breakeven_TriggerPips, Breakeven_OffsetPips,
                          ot, MinHoldHours * 3600, Breakeven_Enabled, Breakeven_RespectMinHold);
      if(PositionSelectByTicket(pos_ticket))
        {
         TradeApplyTrailing(_Symbol, Magic, TrailingStop_Pips, pip, ot, MinHoldHours * 3600,
                            TrailingStop_Enabled, Trailing_OnlyAfterBreakeven, Breakeven_OffsetPips);
        }
     }

   if(!new_bar)
      return;

   //--- alerts (once per bar)
   if(EnableAlerts)
     {
      if(Alert_RSI)
        {
         if(AlertDetectRsiCross(g_rsi_handle, RSI_Oversold))
           {
            const string msg = StringFormat("[RSI-OS-EA] RSI crossed below %d | %s %.5f",
                                            RSI_Oversold, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID));
            AlertSendPopup(msg);
            AlertSendPush(msg, Alert_Push);
           }
        }

      if(Alert_Setup && session_gate)
        {
         if(snap.score == SCORE_A || snap.score == SCORE_A_PLUS)
           {
            const string msg = AlertBuildMessage(_Symbol, RSI_Timeframe,
                                                 SymbolInfoDouble(_Symbol, SYMBOL_BID),
                                                 rsi_st.value, snap, session_name);
            AlertSendPopup(msg);
            AlertSendPush(msg, Alert_Push);
           }
        }

      if(Alert_APlus && session_gate)
        {
         if(snap.score == SCORE_A_PLUS)
           {
            const string msg = AlertBuildMessage(_Symbol, RSI_Timeframe,
                                                 SymbolInfoDouble(_Symbol, SYMBOL_BID),
                                                 rsi_st.value, snap, session_name);
            AlertSendPopup(msg);
            AlertSendPush(msg, Alert_Push);
            AlertSendEmail("RSI-OS-EA A+", msg, Alert_Email);
           }
        }
     }

   if(session_gate && snap.score >= SCORE_C)
      WeeklyOnSignal(g_week, snap.score, session_name, _Symbol);

   //--- signal markers §6.3 (Dark Luxury mockup)
   if(session_gate && snap.score >= SCORE_B && snap.score != SCORE_NONE)
     {
      const datetime t1 = iTime(_Symbol, RSI_Timeframe, 1);
      const double bar_low = iLow(_Symbol, RSI_Timeframe, 1);
      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      UiPaintSignalTriangle(t1, bar_low, snap.score);
      UiCountSignalGrade(snap.score);

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl_p = entry - SL_Pips * pip;
      const double tp_p = entry + SL_Pips * RR_Ratio * pip;

      UiHLine("ov_sl", sl_p, UI_CRIMSON, STYLE_DASH, 1);
      UiRightPricePill("ov_sl", sl_p,
                       StringFormat("SL %s", DoubleToString(sl_p, digits)),
                       UI_CRIMSON, UI_BG_MAIN);

      if(TP_Rule == TP_RULE_FIXED_RR)
        {
         UiHLine("ov_tp", tp_p, UI_MINT, STYLE_DASH, 1);
         UiRightPricePill("ov_tp", tp_p,
                          StringFormat("TP %s", DoubleToString(tp_p, digits)),
                          UI_MINT, UI_BG_MAIN);
        }
     }

   //--- auto trade at open of bar following signal bar (first tick of new bar = open)
   if(!EnableTrading)
      return;
   if(AccountInfoDouble(ACCOUNT_BALANCE) < MinBalance)
      return;
   if(RiskDailyBlocked())
     {
      Print("[RSI-OS-EA] Daily loss limit reached — no new trades.");
      return;
     }
   if(Session_FilterEnabled && !london_ny)
      return;

   if(!SetupAutoTradeAllowed(snap.score, g_auto_min_rank, Risk_Use_Per_Setup, Risk_Percent,
                             Risk_Pct_A_Plus, Risk_Pct_A, Risk_Pct_B, Risk_Pct_C))
      return;

   const double risk_pct_use = SetupRiskPercent(snap.score, Risk_Use_Per_Setup, Risk_Percent,
                                                Risk_Pct_A_Plus, Risk_Pct_A, Risk_Pct_B, Risk_Pct_C);
   if(risk_pct_use <= 0.0)
      return;

   const ulong pos_existing = TradeFindPositionTicket(_Symbol, Magic);
   const bool  pyramid_entry = (pos_existing != 0);

   if(pyramid_entry)
     {
      if(!Pyramid_Enabled)
         return;
      if(s_pyramid_adds >= Pyramid_MaxAdds)
         return;
      if(!PositionSelectByTicket(pos_existing))
         return;
      const double entry_px = PositionGetDouble(POSITION_PRICE_OPEN);
      const double bid_chk = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double one_r = SL_Pips * pip;
      if(one_r <= 0.0)
         return;
      if((bid_chk - entry_px) / one_r < Pyramid_MinProfitR)
         return;
      if(s_pyramid_anchor > 0)
        {
         const int wait_sec = Pyramid_MinBarsBetween * (int)PeriodSeconds(RSI_Timeframe);
         if(TimeCurrent() - s_pyramid_anchor < wait_sec)
            return;
        }
     }
   else
     {
      if(RiskCountPositions(_Symbol, Magic) >= MaxConcurrentTrades)
         return;
     }

   const double lots = RiskComputeLots(_Symbol, AccountInfoDouble(ACCOUNT_BALANCE),
                                       risk_pct_use, SL_Pips, pip);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double sl_price = ask - SL_Pips * pip;
   const double tp_price = (TP_Rule == TP_RULE_OPEN) ? 0.0 : (ask + SL_Pips * RR_Ratio * pip);

   CTrade trade;
   trade.SetExpertMagicNumber((ulong)Magic);
   trade.SetDeviationInPoints(50);
   const long fill = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fill & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      trade.SetTypeFilling(ORDER_FILLING_IOC);
   else if((fill & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      trade.SetTypeFilling(ORDER_FILLING_FOK);
   else
      trade.SetTypeFilling(ORDER_FILLING_RETURN);

   if(!trade.Buy(lots, _Symbol, ask, sl_price, tp_price, TradeComment))
     {
      Print("[RSI-OS-EA] Order failed: ", trade.ResultRetcodeDescription());
      return;
     }

   g_week.trades_placed++;

   long pos_id = 0;
   double pos_vol = 0.0;
   for(int pi = PositionsTotal() - 1; pi >= 0; pi--)
     {
      const ulong tkt = PositionGetTicket(pi);
      if(tkt == 0 || !PositionSelectByTicket(tkt))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != Magic)
         continue;
      pos_id = (long)PositionGetInteger(POSITION_IDENTIFIER);
      pos_vol = PositionGetDouble(POSITION_VOLUME);
      break;
     }

   if(pyramid_entry)
     {
      s_pyramid_adds++;
      s_pyramid_anchor = TimeCurrent();
      OpenCacheUpdateLots(pos_id, pos_vol);
      Print("[RSI-OS-EA] Pyramid add lots=", lots, " totalVol=", pos_vol, " SL=", sl_price, " TP=", tp_price);
     }
   else
     {
      s_pyramid_adds = 0;
      s_pyramid_anchor = TimeCurrent();

      SOpenContext oc;
      oc.position_id = pos_id;
      oc.open_time = TimeCurrent();
      oc.entry = ask;
      oc.lots = pos_vol > 0.0 ? pos_vol : lots;
      oc.sl = sl_price;
      oc.tp = tp_price;
      oc.sl_pips = SL_Pips;
      oc.snap = snap;
      oc.rsi_val = rsi_st.value;
      oc.session_name = session_name;
      OpenCacheAdd(oc);

      Print("[RSI-OS-EA] BUY opened lots=", oc.lots, " SL=", sl_price, " TP=", tp_price);
     }
  }

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != Magic)
      return;

   const long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT)
      return;

   const long pos_id = (long)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   SOpenContext ctx;
   if(!OpenCacheTake(pos_id, ctx))
      return;

   const double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                         + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                         + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   if(profit >= 0.0)
      g_week.wins++;
   else
      g_week.losses++;
   g_week.pnl_usd += profit;

   const datetime ct = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   const double cp = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   const double vol_close = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   const int hold_min = (int)((ct - ctx.open_time) / 60);
   if(hold_min < 0)
      return;

   if(LogTrades_CSV)
      TradeLoggerWriteRow(LogPath, pos_id, ctx.open_time, _Symbol, RSI_Timeframe,
                          ctx.entry, vol_close, ctx.sl, ctx.tp, ctx.sl_pips,
                          ctx.snap, ctx.rsi_val, ctx.session_name,
                          ct, cp, "CLOSE", profit, hold_min);
  }

//+------------------------------------------------------------------+
void UiDashboardRenderFromCache()
  {
   if(!g_ui_cache.valid)
     {
      UiDashboardToggleEnsure();
      if(g_dashboard_collapsed)
         UiClearDashboardExceptToggle();
      ChartRedraw(0);
      return;
     }
   UiDashboardRender(g_ui_cache.trading_on, g_ui_cache.rsi_live, g_ui_cache.snap,
                     g_ui_cache.disp_c1, g_ui_cache.disp_c2, g_ui_cache.disp_c3,
                     g_ui_cache.disp_c4, g_ui_cache.disp_c5,
                     g_ui_cache.psych_level, g_ui_cache.psych_dist,
                     g_ui_cache.sup_level, g_ui_cache.sup_dist,
                     g_ui_cache.session_name, MinHoldHours, g_week);
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   const string card = OBJ_UI_PREFIX + "card_main";
   const string tbtn = OBJ_UI_PREFIX + "dash_toggle";

   // Drag-and-drop: panel follows card_main rectangle
   if(id == CHARTEVENT_OBJECT_DRAG && sparam == card)
     {
      g_ui_dx = (int)ObjectGetInteger(0, card, OBJPROP_XDISTANCE);
      g_ui_dy = (int)ObjectGetInteger(0, card, OBJPROP_YDISTANCE);
      if(g_ui_dx < 0) g_ui_dx = 0;
      if(g_ui_dy < 28) g_ui_dy = 28;
      UiDashboardRenderFromCache();
      return;
     }

   if(id == CHARTEVENT_OBJECT_CHANGE && sparam == card)
     {
      g_ui_dx = (int)ObjectGetInteger(0, card, OBJPROP_XDISTANCE);
      g_ui_dy = (int)ObjectGetInteger(0, card, OBJPROP_YDISTANCE);
      UiDashboardRenderFromCache();
      return;
     }

   if(id != CHARTEVENT_OBJECT_CLICK)
      return;
   if(sparam != tbtn)
      return;
   g_dashboard_collapsed = !g_dashboard_collapsed;
   if(ObjectFind(0, tbtn) >= 0)
      ObjectSetInteger(0, tbtn, OBJPROP_STATE, false);
   UiDashboardRenderFromCache();
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
