//+------------------------------------------------------------------+
//|            Modified Moving Averages(barabashkakvn's edition).mq5 |
//|                                           yuripk  rebek@narod.ru |
//+------------------------------------------------------------------+
#property link      "yuripk  rebek@narod.ru"
#property version   "1.001"

#include <Trade\Trade.mqh>

input double Lots             = -0.1;     // Lots
input double MaximumRisk      = 0.02;     // Maximum Risk in percentage
input double DecreaseFactor   = 3;        // Decrease factor
input int    MovingPeriod     = 12;       // Moving Average period
input int    MovingShift      = 6;        // Moving Average shift
input ushort StopLoss         = 105;      // StopLoss
input ushort TakeProfit       = 285;      // TakeProfit
//---
int    ExtHandle=0;
bool   ExtHedging=false;
CTrade ExtTrade;

#define MA_MAGIC 1234501

double m_adjusted_point;                  // point value adjusted for 3 or 5 points
//+------------------------------------------------------------------+
//| Calculate optimal lot size                                       |
//+------------------------------------------------------------------+
double TradeSizeOptimized(void)
  {
   double price=0.0;
   double margin=0.0;
//--- select lot size
   if(!SymbolInfoDouble(Symbol(),SYMBOL_ASK,price))
      return(0.0);
   if(!OrderCalcMargin(ORDER_TYPE_BUY,Symbol(),1.0,price,margin))
      return(0.0);
   if(margin<=0.0)
      return(0.0);

   double lot=NormalizeDouble(AccountInfoDouble(ACCOUNT_MARGIN_FREE)*MaximumRisk/margin,2);
   if(Lots<0)
      return(-Lots);
//--- calculate number of losses orders without a break
   if(DecreaseFactor>0)
     {
      //--- select history for access
      HistorySelect(0,TimeCurrent());
      //---
      int    orders=HistoryDealsTotal();  // total history deals
      int    losses=0;                    // number of losses orders without a break

      for(int i=orders-1;i>=0;i--)
        {
         ulong ticket=HistoryDealGetTicket(i);
         if(ticket==0)
           {
            Print("HistoryDealGetTicket failed, no trade history");
            break;
           }
         //--- check symbol
         if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=Symbol())
            continue;
         //--- check Expert Magic number
         if(HistoryDealGetInteger(ticket,DEAL_MAGIC)!=MA_MAGIC)
            continue;
         //--- check profit
         double profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);
         if(profit>0.0)
            break;
         if(profit<0.0)
            losses++;
        }
      //---
      if(losses>1)
         lot=NormalizeDouble(lot-lot*losses/DecreaseFactor,1);
     }
//--- normalize and check limits
   double stepvol=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
   lot=stepvol*NormalizeDouble(lot/stepvol,0);

   double minvol=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   if(lot<minvol)
      lot=minvol;

   double maxvol=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   if(lot>maxvol)
      lot=maxvol;
//--- return trading volume
   return(lot);
  }
//+------------------------------------------------------------------+
//| Check for open position conditions                               |
//+------------------------------------------------------------------+
void CheckForOpen(void)
  {
   MqlRates rt[2];
//--- go trading only for first ticks of new bar
   if(CopyRates(Symbol(),_Period,0,2,rt)!=2)
     {
      Print("CopyRates of ",Symbol()," failed, no history");
      return;
     }
   if(rt[1].tick_volume>1)
      return;
//--- get current Moving Average 
   double   ma[1];
   if(CopyBuffer(ExtHandle,0,0,1,ma)!=1)
     {
      Print("CopyBuffer from iMA failed, no data");
      return;
     }
//--- check signals
   ENUM_ORDER_TYPE signal=WRONG_VALUE;

   if(rt[0].open>ma[0] && rt[0].close<ma[0])
      signal=ORDER_TYPE_SELL;    // sell conditions
   else
     {
      if(rt[0].open<ma[0] && rt[0].close>ma[0])
         signal=ORDER_TYPE_BUY;  // buy conditions
     }
//--- additional checking
   if(signal!=WRONG_VALUE)
     {
      double price=SymbolInfoDouble(Symbol(),signal==ORDER_TYPE_SELL ? SYMBOL_BID:SYMBOL_ASK);
      double sl=0.0;
      if(StopLoss>0)
         sl=(signal==ORDER_TYPE_SELL) ? price+StopLoss*Point():price-StopLoss*Point();
      double tp=0.0;
      if(TakeProfit>0)
         tp=(signal==ORDER_TYPE_SELL) ? price-TakeProfit*Point():price+TakeProfit*Point();
      if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && Bars(Symbol(),_Period)>100)
         ExtTrade.PositionOpen(Symbol(),signal,TradeSizeOptimized(),
                               price,sl,tp);
     }
//---
  }
//+------------------------------------------------------------------+
//| Check for close position conditions                              |
//+------------------------------------------------------------------+
void CheckForClose(void)
  {
   MqlRates rt[2];
//--- go trading only for first ticks of new bar
   if(CopyRates(Symbol(),_Period,0,2,rt)!=2)
     {
      Print("CopyRates of ",Symbol()," failed, no history");
      return;
     }
   if(rt[1].tick_volume>1)
      return;
//--- get current Moving Average 
   double   ma[1];
   if(CopyBuffer(ExtHandle,0,0,1,ma)!=1)
     {
      Print("CopyBuffer from iMA failed, no data");
      return;
     }
//--- positions already selected before
   bool signal=false;
   long type=PositionGetInteger(POSITION_TYPE);

   if(type==(long)POSITION_TYPE_BUY && rt[0].open>ma[0] && rt[0].close<ma[0])
      signal=true;
   if(type==(long)POSITION_TYPE_SELL && rt[0].open<ma[0] && rt[0].close>ma[0])
      signal=true;
//--- additional checking
   if(signal)
     {
      if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && Bars(Symbol(),_Period)>100)
         ExtTrade.PositionClose(Symbol(),3);
     }
//---
  }
//+------------------------------------------------------------------+
//| Position select depending on netting or hedging                  |
//+------------------------------------------------------------------+
bool SelectPosition()
  {
   bool res=false;
//--- check position in Hedging mode
   if(ExtHedging)
     {
      uint total=PositionsTotal();
      for(uint i=0; i<total; i++)
        {
         string position_symbol=PositionGetSymbol(i);
         if(Symbol()==position_symbol && MA_MAGIC==PositionGetInteger(POSITION_MAGIC))
           {
            res=true;
            break;
           }
        }
     }
//--- check position in Netting mode
   else
     {
      if(!PositionSelect(Symbol()))
         return(false);
      else
         return(PositionGetInteger(POSITION_MAGIC)==MA_MAGIC); //---check Magic number
     }
//--- result for Hedging mode
   return(res);
  }
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(void)
  {
//--- prepare trade class to control positions if hedging mode is active
   ExtHedging=((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   ExtTrade.SetExpertMagicNumber(MA_MAGIC);
   ExtTrade.SetMarginMode();
   ExtTrade.SetTypeFillingBySymbol(Symbol());
//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(Digits()==3 || Digits()==5)
      digits_adjust=10;
   m_adjusted_point=Point()*digits_adjust;
//--- Moving Average indicator
   ExtHandle=iMA(Symbol(),_Period,MovingPeriod,MovingShift,MODE_SMA,PRICE_CLOSE);
   if(ExtHandle==INVALID_HANDLE)
     {
      printf("Error creating MA indicator");
      return(INIT_FAILED);
     }
//--- ok
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(void)
  {
//---
   if(SelectPosition())
      CheckForClose();
   else
      CheckForOpen();
//---
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }
//+------------------------------------------------------------------+
