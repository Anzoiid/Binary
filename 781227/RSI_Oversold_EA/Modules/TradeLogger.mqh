//+------------------------------------------------------------------+
//| TradeLogger.mqh                                                  |
//| Append CSV to MQL5/Files (PRD §3.12)                             |
//+------------------------------------------------------------------+
#ifndef RSI_OS_LOGGER_MQH
#define RSI_OS_LOGGER_MQH
#include "SetupScorer.mqh"

/**
 * Single full row append (call on trade close with complete data).
 */
bool TradeLoggerWriteRow(const string rel_path,
                         const long trade_id,
                         const datetime open_time,
                         const string symbol,
                         const ENUM_TIMEFRAMES tf,
                         const double entry_price,
                         const double lot_size,
                         const double sl_price,
                         const double tp_price,
                         const int sl_pips,
                         const SSetupSnapshot &snap,
                         const double rsi_value,
                         const string session_name,
                         const datetime close_time,
                         const double close_price,
                         const string close_reason,
                         const double pnl_usd,
                         const int hold_minutes)
  {
   const int h = FileOpen(rel_path, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE)
     {
      Print("[RSI-OS-EA] CSV open failed: ", rel_path, " err=", GetLastError());
      return false;
     }

   FileSeek(h, 0, SEEK_END);
   if(FileSize(h) == 0)
     {
      FileWrite(h,
                "TradeID", "OpenTime", "Symbol", "Timeframe", "EntryPrice", "LotSize",
                "SL_Price", "TP_Price", "SL_Pips", "Score",
                "C1_RSI", "C2_Sweep", "C3_Session", "C4_Psych", "C5_ProtectedLow",
                "RSI_Value", "Session", "CloseTime", "ClosePrice", "CloseReason", "PnL_USD", "HoldDuration_Min");
     }

   FileWrite(h,
             trade_id,
             TimeToString(open_time, TIME_DATE | TIME_SECONDS),
             symbol,
             EnumToString(tf),
             DoubleToString(entry_price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
             lot_size,
             DoubleToString(sl_price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
             DoubleToString(tp_price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
             sl_pips,
             snap.score_label,
             snap.c1_rsi ? 1 : 0,
             snap.c2_sweep ? 1 : 0,
             snap.c3_session ? 1 : 0,
             snap.c4_psych ? 1 : 0,
             snap.c5_protected_low ? 1 : 0,
             DoubleToString(rsi_value, 2),
             session_name,
             TimeToString(close_time, TIME_DATE | TIME_SECONDS),
             DoubleToString(close_price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
             close_reason,
             DoubleToString(pnl_usd, 2),
             hold_minutes);
   FileClose(h);
   return true;
  }

#endif
