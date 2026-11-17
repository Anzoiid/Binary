//+------------------------------------------------------------------+
//| SetupScorer.mqh                                                  |
//| PRD §3.7 — A+, A, B, C, No Signal                                |
//+------------------------------------------------------------------+
#ifndef RSI_OS_SCORER_MQH
#define RSI_OS_SCORER_MQH

enum ESetupScore
  {
   SCORE_NONE = 0,
   SCORE_C,
   SCORE_B,
   SCORE_A,
   SCORE_A_PLUS
  };

struct SSetupSnapshot
  {
   bool              c1_rsi;
   bool              c2_sweep;
   bool              c3_session;
   bool              c4_psych;
   bool              c5_protected_low;
   ESetupScore       score;
   int               criteria_met; // count out of 5
   string            score_label;
  };

/**
 * Classify setup from five booleans (all false if upstream skipped).
 */
void ScoreClassify(const bool c1, const bool c2, const bool c3, const bool c4, const bool c5,
                   SSetupSnapshot &out)
  {
   out.c1_rsi = c1;
   out.c2_sweep = c2;
   out.c3_session = c3;
   out.c4_psych = c4;
   out.c5_protected_low = c5;
   out.criteria_met = 0;
   if(c1)
      out.criteria_met++;
   if(c2)
      out.criteria_met++;
   if(c3)
      out.criteria_met++;
   if(c4)
      out.criteria_met++;
   if(c5)
      out.criteria_met++;

   out.score = SCORE_NONE;
   out.score_label = "—";

   if(!c1)
     {
      out.score = SCORE_NONE;
      out.score_label = "No Signal";
      return;
     }

   if(c1 && c2 && c3 && (c4 || c5))
     {
      out.score = SCORE_A_PLUS;
      out.score_label = "A+";
      return;
     }

   if(c1 && c2 && c3)
     {
      out.score = SCORE_A;
      out.score_label = "A";
      return;
     }

   const bool xor23 = (c2 && !c3) || (!c2 && c3);
   if(c1 && xor23)
     {
      out.score = SCORE_B;
      out.score_label = "B";
      return;
     }

   if(c1 && !c2 && !c3)
     {
      out.score = SCORE_C;
      out.score_label = "C";
      return;
     }

   out.score = SCORE_NONE;
   out.score_label = "No Signal";
  }

/**
 * Minimum auto-trade score: A+ or A string from input.
 */
bool ScoreMeetsMinAuto(const ESetupScore sc, const bool want_a_plus_only)
  {
   if(want_a_plus_only)
      return (sc == SCORE_A_PLUS);
   return (sc == SCORE_A_PLUS || sc == SCORE_A);
  }

/** Rank for tier comparison: A+=4 … C=1 */
int SetupScoreRank(const ESetupScore sc)
  {
   if(sc == SCORE_A_PLUS)
      return 4;
   if(sc == SCORE_A)
      return 3;
   if(sc == SCORE_B)
      return 2;
   if(sc == SCORE_C)
      return 1;
   return 0;
  }

bool SetupScoreAtLeast(const ESetupScore sc, const int min_rank)
  {
   const int r = SetupScoreRank(sc);
   return (r > 0 && r >= min_rank);
  }

/**
 * Risk % for this setup when per-setup sizing is enabled (0 = do not auto-trade tier).
 */
double SetupRiskPercent(const ESetupScore sc, const bool use_per_setup, const double risk_legacy,
                        const double pct_a_plus, const double pct_a, const double pct_b, const double pct_c)
  {
   if(!use_per_setup)
      return risk_legacy;
   if(sc == SCORE_A_PLUS)
      return pct_a_plus;
   if(sc == SCORE_A)
      return pct_a;
   if(sc == SCORE_B)
      return pct_b;
   if(sc == SCORE_C)
      return pct_c;
   return 0.0;
  }

/**
 * Auto-trade allowed: positive risk for tier + minimum tier (4=A+ only … 1=C).
 */
bool SetupAutoTradeAllowed(const ESetupScore sc, const int min_rank,
                           const bool use_per_setup, const double risk_legacy,
                           const double pct_a_plus, const double pct_a, const double pct_b, const double pct_c)
  {
   const double rp = SetupRiskPercent(sc, use_per_setup, risk_legacy, pct_a_plus, pct_a, pct_b, pct_c);
   if(rp <= 0.0)
      return false;
   return SetupScoreAtLeast(sc, min_rank);
  }

#endif
