//+------------------------------------------------------------------+
//| Common.mqh                                                       |
//| Shared helpers: pip size, symbol normalization                  |
//+------------------------------------------------------------------+
#ifndef RSI_OS_COMMON_MQH
#define RSI_OS_COMMON_MQH

/**
 * Broker-normalized "one pip" in price units for P&L distance math.
 * Uses point and digits (standard MT5: 5-digit FX → pip = 10 points).
 */
double PipSize(const string symbol)
  {
   const double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(pt <= 0.0)
      return 0.0;
   const int dg = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(dg == 3 || dg == 5)
      return pt * 10.0;
   return pt;
  }

/**
 * Money risk per 1 lot for SL distance in price (approximate for metals).
 */
double MoneyPerLotForDistance(const string symbol, const double distance_price)
  {
   const double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tick_size <= 0.0 || tick_value <= 0.0 || distance_price <= 0.0)
      return 0.0;
   return (distance_price / tick_size) * tick_value;
  }

#endif
