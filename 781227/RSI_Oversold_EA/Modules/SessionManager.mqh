//+------------------------------------------------------------------+
//| SessionManager.mqh                                               |
//| UTC sessions via TimeGMT(); overlap 13–16 UTC counts as NY      |
//+------------------------------------------------------------------+
#ifndef RSI_OS_SESSION_MQH
#define RSI_OS_SESSION_MQH

enum ESessionLabel
  {
   SESSION_ASIAN = 0,
   SESSION_LONDON,
   SESSION_NY,
   SESSION_OVERNIGHT,
   SESSION_UNKNOWN
  };

/**
 * Hour [0,23] from UTC time.
 */
int SessionUtcHour(const datetime t_gmt)
  {
   MqlDateTime dt;
   TimeToStruct(t_gmt, dt);
   return (int)dt.hour;
  }

/**
 * True if hour is within [start, end) with wrap for overnight ranges not used here.
 */
bool HourInRange(const int hour, const int start_inclusive, const int end_exclusive)
  {
   if(start_inclusive < end_exclusive)
      return (hour >= start_inclusive && hour < end_exclusive);
   // wrap: e.g. 22–08
   return (hour >= start_inclusive || hour < end_exclusive);
  }

/**
 * London: [London_Start, London_End), NY: [NY_Start, NY_End).
 * Overlap [max(London_Start,NY_Start), min(London_End,NY_End)) → NY for labeling.
 */
void SessionGetLabel(const int hour_utc,
                     const int london_start, const int london_end,
                     const int ny_start, const int ny_end,
                     ESessionLabel &out_label, string &out_name)
  {
   const bool in_london = HourInRange(hour_utc, london_start, london_end);
   const bool in_ny = HourInRange(hour_utc, ny_start, ny_end);
   if(in_london && in_ny)
     {
      out_label = SESSION_NY;
      out_name = "NY (overlap)";
      return;
     }
   if(in_ny)
     {
      out_label = SESSION_NY;
      out_name = "NY";
      return;
     }
   if(in_london)
     {
      out_label = SESSION_LONDON;
      out_name = "London";
      return;
     }
   // Asian 22:00–08:00 UTC per PRD table (approximation when not London/NY)
   if(HourInRange(hour_utc, 22, 24) || HourInRange(hour_utc, 0, 8))
     {
      out_label = SESSION_ASIAN;
      out_name = "Asian";
      return;
     }
   out_label = SESSION_OVERNIGHT;
   out_name = "Overnight";
  }

/**
 * C3: tradable London/NY window (either session, overlap = NY label but still allowed).
 */
bool SessionIsLondonOrNY(const int hour_utc,
                         const int london_start, const int london_end,
                         const int ny_start, const int ny_end)
  {
   const bool in_london = HourInRange(hour_utc, london_start, london_end);
   const bool in_ny = HourInRange(hour_utc, ny_start, ny_end);
   return (in_london || in_ny);
  }

#endif
