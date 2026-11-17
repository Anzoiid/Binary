//+------------------------------------------------------------------+
//| AlertSystem.mqh                                                  |
//| Popup, SendNotification, SendMail                                |
//+------------------------------------------------------------------+
#ifndef RSI_OS_ALERT_MQH
#define RSI_OS_ALERT_MQH
#include "SetupScorer.mqh"

/**
 * RSI cross below oversold on closed bars: RSI[2] > th && RSI[1] <= th.
 */
bool AlertDetectRsiCross(const int rsi_handle, const int oversold_level)
  {
   double r1 = 0, r2 = 0;
   double a1[], a2[];
   ArraySetAsSeries(a1, true);
   ArraySetAsSeries(a2, true);
   if(CopyBuffer(rsi_handle, 0, 1, 1, a1) != 1)
      return false;
   if(CopyBuffer(rsi_handle, 0, 2, 1, a2) != 1)
      return false;
   r1 = a1[0];
   r2 = a2[0];
   return (r2 > (double)oversold_level && r1 <= (double)oversold_level);
  }

/**
 * Build alert text per PRD §3.10.3.
 */
string AlertBuildMessage(const string symbol, const ENUM_TIMEFRAMES tf,
                         const double price, const double rsi_val,
                         const SSetupSnapshot &snap, const string session_name)
  {
   string crit = StringFormat("C1=%s C2=%s C3=%s C4=%s C5=%s",
                              snap.c1_rsi ? "Y" : "n",
                              snap.c2_sweep ? "Y" : "n",
                              snap.c3_session ? "Y" : "n",
                              snap.c4_psych ? "Y" : "n",
                              snap.c5_protected_low ? "Y" : "n");
   return StringFormat("[RSI-OS-EA] %s %s | Price=%.5f RSI=%.2f Score=%s | Session=%s | %s",
                       symbol, EnumToString(tf), price, rsi_val, snap.score_label, session_name, crit);
  }

void AlertSendPopup(const string msg)
  {
   Alert(msg);
  }

void AlertSendPush(const string msg, const bool do_push)
  {
   if(do_push)
      SendNotification(msg);
  }

void AlertSendEmail(const string subject, const string body, const bool do_mail)
  {
   if(do_mail)
      SendMail(subject, body);
  }

#endif
