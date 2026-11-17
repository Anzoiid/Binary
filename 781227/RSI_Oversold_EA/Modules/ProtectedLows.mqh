//+------------------------------------------------------------------+
//| ProtectedLows.mqh                                                |
//| Support = Lowest(low, N) at [2] vs bar low[1]                    |
//+------------------------------------------------------------------+
#ifndef RSI_OS_PROTECTED_LOWS_MQH
#define RSI_OS_PROTECTED_LOWS_MQH
#include "Common.mqh"

/**
 * PRD §3.6.1: support = Lowest(low, Lows_Lookback)[2] on series.
 */
bool ProtectedLowSupport(const string symbol, const ENUM_TIMEFRAMES tf,
                         const int lookback, double &out_support)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int need = lookback + 4;
   if(CopyRates(symbol, tf, 0, need, rates) < need)
      return false;

   double lowest = rates[2].low;
   for(int i = 3; i <= 1 + lookback && i < ArraySize(rates); i++)
     {
      if(rates[i].low < lowest)
         lowest = rates[i].low;
     }
   out_support = lowest;
   return true;
  }

/**
 * C5: |low[shift] - support| / pip <= Lows_Distance
 * support = Lowest(low) over (shift+1 .. shift+lookback)
 */
bool ProtectedLowCriterionAt(const string symbol, const ENUM_TIMEFRAMES tf,
                             const int shift, const int lookback, const int max_dist_pips,
                             const double pip, double &out_support, double &out_dist_pips)
  {
   out_support = 0.0;
   out_dist_pips = 999999.0;
   if(shift < 1 || lookback < 2 || pip <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int need = shift + lookback + 3;
   if(CopyRates(symbol, tf, 0, need, rates) < need)
      return false;

   double lowest = rates[shift + 1].low;
   for(int i = shift + 2; i <= shift + lookback && i < ArraySize(rates); i++)
     {
      if(rates[i].low < lowest)
         lowest = rates[i].low;
     }
   out_support = lowest;
   out_dist_pips = MathAbs(rates[shift].low - out_support) / pip;
   return (out_dist_pips <= (double)max_dist_pips);
  }

/**
 * C5 on last closed bar [1] (compat wrapper).
 */
bool ProtectedLowCriterion(const string symbol, const ENUM_TIMEFRAMES tf,
                           const int lookback, const int max_dist_pips, const double pip,
                           double &out_support, double &out_dist_pips)
  {
   return ProtectedLowCriterionAt(symbol, tf, 1, lookback, max_dist_pips, pip,
                                  out_support, out_dist_pips);
  }

#endif
