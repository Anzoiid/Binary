//+------------------------------------------------------------------+
//| TradeManager.mqh                                                 |
//| Entry, SL/TP, min hold, breakeven, trailing                      |
//+------------------------------------------------------------------+
#ifndef RSI_OS_TRADE_MGR_MQH
#define RSI_OS_TRADE_MGR_MQH
#include <Trade\Trade.mqh>
#include "Common.mqh"
#include "RiskManager.mqh"

struct STradeOpenContext
  {
   double            entry;
   double            sl;
   double            tp;
   double            lots;
   datetime          signal_time;
  };

/**
 * Open BUY with SL/TP; respects EnableTrading externally.
 */
bool TradeOpenBuy(const string symbol, const long magic, const string comment,
                  const double lots, const double sl_price, const double tp_price)
  {
   CTrade trade;
   trade.SetExpertMagicNumber((ulong)magic);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   return trade.Buy(lots, symbol, ask, sl_price, tp_price, comment);
  }

/**
 * Find position ticket for symbol+magic.
 */
ulong TradeFindPositionTicket(const string symbol, const long magic)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return ticket;
     }
   return 0;
  }

/**
 * True if BUY position SL is at or above entry + offset (breakeven reached).
 */
bool TradeIsBreakevenOrBetter(const string symbol, const ulong ticket, const double pip,
                              const int offset_pips)
  {
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;
   if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
      return false;
   const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   const double sl = PositionGetDouble(POSITION_SL);
   const double be_level = entry + offset_pips * pip;
   return (sl >= be_level - pip * 0.25);
  }

/**
 * Move SL to entry + offset pips when floating profit >= trigger pips (BUY).
 */
void TradeApplyBreakeven(const string symbol, const long magic, const double pip,
                         const int trigger_pips, const int offset_pips,
                         const datetime open_time, const int min_hold_sec,
                         const bool be_enabled, const bool respect_minhold)
  {
   if(!be_enabled || trigger_pips <= 0 || pip <= 0.0)
      return;
   if(respect_minhold && TimeCurrent() < open_time + min_hold_sec)
      return;

   const ulong ticket = TradeFindPositionTicket(symbol, magic);
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return;
   if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
      return;

   const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double profit_dist = bid - entry;
   if(profit_dist < trigger_pips * pip)
      return;

   const double new_sl = entry + offset_pips * pip;
   const double sl_curr = PositionGetDouble(POSITION_SL);
   if(new_sl <= sl_curr + pip * 0.1)
      return;

   CTrade trade;
   trade.SetExpertMagicNumber((ulong)magic);
   trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
  }

/**
 * Trailing stop after MinHoldHours; optional only if breakeven already set.
 */
void TradeApplyTrailing(const string symbol, const long magic,
                        const int trailing_pips, const double pip,
                        const datetime open_time, const int min_hold_sec,
                        const bool trailing_enabled,
                        const bool only_after_breakeven, const int be_offset_pips)
  {
   if(!trailing_enabled || trailing_pips <= 0 || pip <= 0.0)
      return;
   if(TimeCurrent() < open_time + min_hold_sec)
      return;

   const ulong ticket = TradeFindPositionTicket(symbol, magic);
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return;

   if(only_after_breakeven && !TradeIsBreakevenOrBetter(symbol, ticket, pip, be_offset_pips))
      return;

   const double sl_curr = PositionGetDouble(POSITION_SL);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double new_sl = bid - trailing_pips * pip;

   const long type = PositionGetInteger(POSITION_TYPE);
   if(type != POSITION_TYPE_BUY)
      return;

   if(new_sl > sl_curr && new_sl < bid)
     {
      CTrade trade;
      trade.SetExpertMagicNumber((ulong)magic);
      trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
     }
  }

#endif
