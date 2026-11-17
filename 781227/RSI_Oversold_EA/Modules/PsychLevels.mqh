//+------------------------------------------------------------------+
//| PsychLevels.mqh                                                  |
//| XAUUSD: multiples of 50; XAGUSD: multiples of 0.50             |
//+------------------------------------------------------------------+
#ifndef RSI_OS_PSYCH_MQH
#define RSI_OS_PSYCH_MQH
#include "Common.mqh"

/**
 * Nearest psychological level and distance in pips from `price`.
 */
void PsychNearest(const string symbol, const double price,
                  double &out_level, double &out_dist_pips, const double pip)
  {
   out_level = price;
   out_dist_pips = 0.0;
   if(pip <= 0.0)
      return;

   string s = symbol;
   StringToUpper(s);
   const bool is_gold = (StringFind(s, "XAU") >= 0);
   const bool is_silver = (StringFind(s, "XAG") >= 0);

   double step = 50.0;
   if(is_silver)
      step = 0.50;
   else if(!is_gold)
      step = MathPow(10.0, MathMax(0, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS) - 2));

   const double q = price / step;
   const double down = MathFloor(q) * step;
   const double up = MathCeil(q) * step;
   double d1 = MathAbs(price - down);
   double d2 = MathAbs(up - price);
   if(d1 <= d2)
      out_level = down;
   else
      out_level = up;

   out_dist_pips = MathAbs(price - out_level) / pip;
  }

/**
 * C4: within Psych_Distance pips of nearest psych level (if enabled).
 */
bool PsychCriterion(const bool enabled, const string symbol, const double bar_low,
                    const int max_dist_pips, const double pip,
                    double &out_level, double &out_dist_pips)
  {
   PsychNearest(symbol, bar_low, out_level, out_dist_pips, pip);
   if(!enabled)
      return false;
   return (out_dist_pips <= (double)max_dist_pips);
  }

#endif
