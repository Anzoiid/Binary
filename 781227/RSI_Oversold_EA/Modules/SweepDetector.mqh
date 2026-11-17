//+------------------------------------------------------------------+
//| SweepDetector.mqh                                              |
//| Liquidity sweep on last closed bar (index 1)                     |
//+------------------------------------------------------------------+
#ifndef RSI_OS_SWEEP_MQH
#define RSI_OS_SWEEP_MQH
#include "Common.mqh"

/**
 * PRD §3.3.1 on bar `shift` (use 1 for last closed):
 * low[1] < Lowest(low, N)[2]  → compare prior swing excluding current bar.
 * Wick: (min(O,C)-L) / max(|C-O|, pip) >= Sweep_WickRatio
 */
bool SweepDetect(const string symbol, const ENUM_TIMEFRAMES tf,
                 const int shift, const int lookback, const double wick_ratio,
                 const double pip)
  {
   if(lookback < 3 || pip <= 0.0)
      return false;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int need = lookback + shift + 3;
   if(CopyRates(symbol, tf, 0, need, rates) < need)
      return false;
   if(shift + 2 >= ArraySize(rates))
      return false;

   double lowest = rates[shift + 1].low;
   const int from = shift + 2;
   const int to = shift + lookback;
   for(int i = from; i <= to && i < ArraySize(rates); i++)
     {
      if(rates[i].low < lowest)
         lowest = rates[i].low;
     }

   const double low_s = rates[shift].low;
   if(!(low_s < lowest))
      return false;

   const double o = rates[shift].open;
   const double c = rates[shift].close;
   const double body = MathAbs(c - o);
   const double denom = MathMax(body, pip);
   const double lower_wick = MathMin(o, c) - low_s;
   if(lower_wick < 0.0)
      return false;
   return (lower_wick / denom) >= wick_ratio;
  }

#endif
