//+------------------------------------------------------------------+
//| RSI_Engine.mqh                                                   |
//| RSI(14) on configurable timeframe, last closed bar only         |
//+------------------------------------------------------------------+
#ifndef RSI_OS_RSI_ENGINE_MQH
#define RSI_OS_RSI_ENGINE_MQH
#include "Common.mqh"

struct SRsiState
  {
   double            value;
   bool              oversold;
   bool              valid;
  };

/**
 * Create RSI handle; caller must release with IndicatorRelease.
 */
int RsiCreateHandle(const string symbol, const ENUM_TIMEFRAMES tf, const int period)
  {
   return iRSI(symbol, tf, period, PRICE_CLOSE);
  }

/**
 * Read RSI at bar index `shift` (0 = forming bar, 1 = last closed).
 */
bool RsiGet(const int handle, const int shift, double &out_rsi)
  {
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, 0, shift, 1, buf) != 1)
      return false;
   out_rsi = buf[0];
   return MathIsValidNumber(out_rsi);
  }

/**
 * Evaluate RSI. Default shift=1 (closed bar) for signal logic.
 * Use shift=0 for live dashboard display.
 */
void RsiEvaluate(const int handle, const int rsi_oversold, SRsiState &out_state,
                 const int shift = 1)
  {
   out_state.valid = false;
   out_state.value = 0.0;
   out_state.oversold = false;
   double r = 0.0;
   if(!RsiGet(handle, shift, r))
      return;
   out_state.valid = true;
   out_state.value = r;
   out_state.oversold = (r <= (double)rsi_oversold);
  }

#endif
