//+------------------------------------------------------------------+
//| RiskManager.mqh                                                  |
//| Lot sizing, daily loss cap, min balance, concurrency            |
//+------------------------------------------------------------------+
#ifndef RSI_OS_RISK_MQH
#define RSI_OS_RISK_MQH
#include "Common.mqh"

/**
 * Normalize volume to broker constraints.
 */
double RiskNormalizeVolume(const string symbol, double vol)
  {
   const double vmin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double vmax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double vstep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(vstep <= 0.0)
      return vmin;
   vol = MathFloor(vol / vstep) * vstep;
   if(vol < vmin)
      vol = vmin;
   if(vol > vmax)
      vol = vmax;
   return vol;
  }

/**
 * PRD §3.9.1 — risk money / money per lot for SL distance.
 */
double RiskComputeLots(const string symbol, const double balance,
                       const double risk_percent, const int sl_pips, const double pip)
  {
   if(balance <= 0.0 || risk_percent <= 0.0 || sl_pips <= 0 || pip <= 0.0)
      return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

   const double sl_dist = sl_pips * pip;
   const double risk_money = balance * (risk_percent / 100.0);
   const double per_lot = MoneyPerLotForDistance(symbol, sl_dist);
   if(per_lot <= 0.0)
      return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

   double lots = risk_money / per_lot;
   return RiskNormalizeVolume(symbol, lots);
  }

/**
 * Count open positions for symbol with magic.
 */
int RiskCountPositions(const string symbol, const long magic)
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      n++;
     }
   return n;
  }

/**
 * Daily realized PnL from deals closed today (GMT day boundary).
 */
double RiskDailyClosedPnl(const long magic)
  {
   MqlDateTime g;
   TimeToStruct(TimeTradeServer(), g);
   g.hour = 0;
   g.min = 0;
   g.sec = 0;
   const datetime day_start = StructToTime(g);

   double pnl = 0.0;
   if(!HistorySelect(day_start, TimeTradeServer()))
      return 0.0;
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;
      pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      pnl += HistoryDealGetDouble(ticket, DEAL_SWAP);
      pnl += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
     }
   return pnl;
  }

#endif
