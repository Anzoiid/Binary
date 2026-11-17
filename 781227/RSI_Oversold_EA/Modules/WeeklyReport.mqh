//+------------------------------------------------------------------+
//| WeeklyReport.mqh                                                 |
//| Monday 00:00 UTC rollover; running week counters                 |
//+------------------------------------------------------------------+
#ifndef RSI_OS_WEEKLY_MQH
#define RSI_OS_WEEKLY_MQH
#include "SetupScorer.mqh"

struct SWeekStats
  {
   int               week_key;
   datetime          week_start;
   int               cnt_a_plus;
   int               cnt_a;
   int               cnt_b;
   int               cnt_c;
   int               cnt_london;
   int               cnt_ny;
   int               cnt_asian;
   int               cnt_xau;
   int               cnt_xag;
   int               trades_placed;
   int               wins;
   int               losses;
   double            pnl_usd;
  };

/**
 * Day-based key (avoids MqlDateTime.day_of_year — not on all terminal builds).
 */
int WeeklyComputeWeekKey(const datetime gmt)
  {
   MqlDateTime t;
   TimeToStruct(gmt, t);
   return t.year * 10000 + t.mon * 100 + t.day;
  }

void WeeklyReset(SWeekStats &st, const datetime gmt_now)
  {
   ZeroMemory(st);
   st.week_key = WeeklyComputeWeekKey(gmt_now);
   st.week_start = gmt_now;
  }

/**
 * Call on init and when Monday 00:00 UTC boundary crossed.
 */
bool WeeklyShouldRollOver(const datetime last_check_gmt, const datetime now_gmt)
  {
   MqlDateTime a, b;
   TimeToStruct(last_check_gmt, a);
   TimeToStruct(now_gmt, b);
   if(b.day_of_week == 1 && a.day_of_week != 1)
      return true;
   if(b.day_of_week == 1 && b.hour == 0 && (a.day != b.day || a.hour != 0))
      return true;
   return false;
  }

void WeeklyOnSignal(SWeekStats &st, const ESetupScore sc, const string session_name,
                    const string symbol)
  {
   if(sc == SCORE_A_PLUS)
      st.cnt_a_plus++;
   else if(sc == SCORE_A)
      st.cnt_a++;
   else if(sc == SCORE_B)
      st.cnt_b++;
   else if(sc == SCORE_C)
      st.cnt_c++;

   if(StringFind(session_name, "London") >= 0)
      st.cnt_london++;
   else if(StringFind(session_name, "NY") >= 0)
      st.cnt_ny++;
   else
      st.cnt_asian++;

   string u = symbol;
   StringToUpper(u);
   if(StringFind(u, "XAU") >= 0)
      st.cnt_xau++;
   else if(StringFind(u, "XAG") >= 0)
      st.cnt_xag++;
  }

string WeeklyFormatReport(const SWeekStats &st, const bool enable_trading)
  {
   const int total = st.cnt_a_plus + st.cnt_a + st.cnt_b + st.cnt_c;
   double rate = 0.0;
   if(total > 0)
      rate = 100.0 * (double)st.cnt_a_plus / (double)total;
   string s = StringFormat(
                 "[RSI-OS-EA] Weekly summary | A+=%d A=%d B=%d C=%d total=%d | A+ rate=%.1f%% | Lon=%d NY=%d Asian=%d | XAU=%d XAG=%d",
                 st.cnt_a_plus, st.cnt_a, st.cnt_b, st.cnt_c, total, rate,
                 st.cnt_london, st.cnt_ny, st.cnt_asian, st.cnt_xau, st.cnt_xag);
   if(enable_trading)
      s += StringFormat(" | Trades=%d W=%d L=%d PnL=%.2f",
                        st.trades_placed, st.wins, st.losses, st.pnl_usd);
   return s;
  }

#endif
