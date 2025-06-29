//+------------------------------------------------------------------+
//|                                                N- candles v2.mq5 |
//|                              Copyright © 2017, Vladimir Karputov |
//|                                           http://wmua.ru/slesar/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2017, Vladimir Karputov"
#property link      "http://wmua.ru/slesar/"
#property version   "2.001"
#property description "We look for N-of identical candles which go in a row"
#property description "New in version 2: Take Profit, Stop Loss, Trailing"
//---
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
//--- input parameter
input uchar    InpN_candles   = 3;           // N identical candles which go in a row 
input double   InpLot         = 0.01;        // Lot
input ushort   InpTakeProfit  = 50;          // Take Profit (in pips)
input ushort   InpStopLoss    = 50;          // Stop Loss (in pips)
input ushort   InpTrailingStop= 10;          // Trailing Stop ("0" -> not trailing)
input ushort   InpTrailingStep= 4;           // Trailing Step (use if Trailing Stop >0)
input ulong    m_magic        = 427474216;   // magic number
input ulong    m_slippage     = 30;          // slippage
//---
double         m_adjusted_point;             // point value adjusted for 3 or 5 points
double         ExtTakeProfit  = 0.0;
double         ExtStopLoss    = 0.0;
double         ExtTrailingStop= 0.0;
double         ExtTrailingStep= 0.0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   m_symbol.Name(Symbol());                  // sets symbol name
   RefreshRates();
   m_symbol.Refresh();

   string err_text="";
   if(!CheckVolumeValue(InpLot,err_text))
     {
      Print(err_text);
      return(INIT_PARAMETERS_INCORRECT);
     }
//---
   m_trade.SetExpertMagicNumber(m_magic);
//---
   if(IsFillingTypeAllowed(Symbol(),SYMBOL_FILLING_FOK))
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if(IsFillingTypeAllowed(Symbol(),SYMBOL_FILLING_IOC))
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
//---
   m_trade.SetDeviationInPoints(m_slippage);
//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=m_symbol.Point()*digits_adjust;
   ExtTakeProfit  = InpTakeProfit   * m_adjusted_point;
   ExtStopLoss    = InpStopLoss     * m_adjusted_point;
   ExtTrailingStop= InpTrailingStop * m_adjusted_point;
   ExtTrailingStep= InpTrailingStep * m_adjusted_point;
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- we work only at the time of the birth of new bar
   static datetime PrevBars=0;
   datetime time_0=iTime(0);
   if(time_0==PrevBars)
      return;
   PrevBars=time_0;

   if(ExtTrailingStop>0.0)
      for(int i=PositionsTotal()-1;i>=0;i--)
         if(m_position.SelectByIndex(i))
            if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
              {
               if(!RefreshRates())
                 {
                  PrevBars=iTime(1);
                  return;
                 }
               TrailingStop(m_position.Ticket(),ExtTrailingStop,ExtTrailingStep);
              }

   MqlRates rates[];
   int copied=CopyRates(NULL,0,1,InpN_candles,rates);
//--- Example:
//--- rates[0].time -> D'2015.05.28 00:00:00'
//--- rates[2].time -> D'2015.06.01 00:00:00'
   if(copied<=0)
     {
      Print("Error copying price data ",GetLastError());
      return;
     }

   bool result=true;
//--- Bull candle. Bear candle.
   int type_of_candles=0;     // "1" -> Bull candle. "-1" ->Bear candle

   for(int i=0;i<copied;i++)
     {
      //--- We define type of the most distant candle
      if(i==0)
        {
         if(rates[i].open<rates[i].close)
            type_of_candles=1;
         else if(rates[i].open>rates[i].close)
            type_of_candles=-1;
         else
           {
            result=false;
            break;
           }

         continue;
        }

      if(type_of_candles==1) // "1" -> Bull candle
        {
         if(rates[i].open>rates[i].close)
           {
            result=false;
            break;
           }
        }
      else // "-1" ->Bear candle
        {
         if(rates[i].open<rates[i].close)
           {
            result=false;
            break;
           }
        }
     }

   if(!result)
      return;

//--- We here. Means we have found N-of candles in a row
   if(type_of_candles==1) // "1" -> Bull candle
     {
      if(!RefreshRates())
        {
         PrevBars=iTime(1);
         return;
        }
      OpenBuy(m_symbol.Bid()-ExtStopLoss,m_symbol.Ask()+ExtTakeProfit);
     }
   else
     {
      if(!RefreshRates())
        {
         PrevBars=iTime(1);
         return;
        }
      OpenSell(m_symbol.Ask()+ExtStopLoss,m_symbol.Bid()-ExtTakeProfit);
     }

   int d=0;
  }
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates()
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
      return(false);
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
      return(false);
//---
   return(true);
  }
//+------------------------------------------------------------------+
//| Check the correctness of the order volume                        |
//+------------------------------------------------------------------+
bool CheckVolumeValue(double volume,string &error_description)
  {
//--- minimal allowed volume for trade operations
   double min_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   if(volume<min_volume)
     {
      error_description=StringFormat("Volume is less than the minimal allowed SYMBOL_VOLUME_MIN=%.2f",min_volume);
      return(false);
     }

//--- maximal allowed volume of trade operations
   double max_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   if(volume>max_volume)
     {
      error_description=StringFormat("Volume is greater than the maximal allowed SYMBOL_VOLUME_MAX=%.2f",max_volume);
      return(false);
     }

//--- get minimal step of volume changing
   double volume_step=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);

   int ratio=(int)MathRound(volume/volume_step);
   if(MathAbs(ratio*volume_step-volume)>0.0000001)
     {
      error_description=StringFormat("Volume is not a multiple of the minimal step SYMBOL_VOLUME_STEP=%.2f, the closest correct volume is %.2f",
                                     volume_step,ratio*volume_step);
      return(false);
     }
   error_description="Correct volume value";
   return(true);
  }
//+------------------------------------------------------------------+ 
//| Checks if the specified filling mode is allowed                  | 
//+------------------------------------------------------------------+ 
bool IsFillingTypeAllowed(string symbol,int fill_type)
  {
//--- Obtain the value of the property that describes allowed filling modes 
   int filling=(int)SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
//--- Return true, if mode fill_type is allowed 
   return((filling & fill_type)==fill_type);
  }
//+------------------------------------------------------------------+ 
//| Get Open for specified bar index                                 | 
//+------------------------------------------------------------------+ 
double iOpen(const int index,string symbol=NULL,ENUM_TIMEFRAMES timeframe=PERIOD_CURRENT)
  {
   if(symbol==NULL)
      symbol=Symbol();
   if(timeframe==0)
      timeframe=Period();
   double Open[1];
   double open=0;
   int copied=CopyOpen(symbol,timeframe,index,1,Open);
   if(copied>0) open=Open[0];
   return(open);
  }
//+------------------------------------------------------------------+ 
//| Get Close for specified bar index                                | 
//+------------------------------------------------------------------+ 
double iClose(const int index,string symbol=NULL,ENUM_TIMEFRAMES timeframe=PERIOD_CURRENT)
  {
   if(symbol==NULL)
      symbol=Symbol();
   if(timeframe==0)
      timeframe=Period();
   double Close[1];
   double close=0;
   int copied=CopyClose(symbol,timeframe,index,1,Close);
   if(copied>0) close=Close[0];
   return(close);
  }
//+------------------------------------------------------------------+ 
//| Get Time for specified bar index                                 | 
//+------------------------------------------------------------------+ 
datetime iTime(const int index,string symbol=NULL,ENUM_TIMEFRAMES timeframe=PERIOD_CURRENT)
  {
   if(symbol==NULL)
      symbol=Symbol();
   if(timeframe==0)
      timeframe=Period();
   datetime Time[1];
   datetime time=0;
   int copied=CopyTime(symbol,timeframe,index,1,Time);
   if(copied>0) time=Time[0];
   return(time);
  }
//+------------------------------------------------------------------+
//| Open Buy position                                                |
//+------------------------------------------------------------------+
void OpenBuy(double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double chek_volime_lot=m_trade.CheckVolume(m_symbol.Name(),InpLot,m_symbol.Ask(),ORDER_TYPE_BUY);

   if(chek_volime_lot!=0.0)
      if(chek_volime_lot>=InpLot)
        {
         if(m_trade.Buy(InpLot,NULL,m_symbol.Ask(),sl,tp))
           {
            if(m_trade.ResultDeal()==0)
              {
               Print("Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
            else
              {
               Print("Buy -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
           }
         else
           {
            Print("Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
           }
        }
//---
  }
//+------------------------------------------------------------------+
//| Open Sell position                                               |
//+------------------------------------------------------------------+
void OpenSell(double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double chek_volime_lot=m_trade.CheckVolume(m_symbol.Name(),InpLot,m_symbol.Bid(),ORDER_TYPE_SELL);

   if(chek_volime_lot!=0.0)
      if(chek_volime_lot>=InpLot)
        {
         if(m_trade.Sell(InpLot,NULL,m_symbol.Bid(),sl,tp))
           {
            if(m_trade.ResultDeal()==0)
              {
               Print("Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
            else
              {
               Print("Sell -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
              }
           }
         else
           {
            Print("Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
           }
        }
//---
  }
//+------------------------------------------------------------------+
//| Trailing position                                                |
//|  With this approach, it is expected that the position            |
//|  is ALREADY SELECTED and the prices are updated                  |
//|  in the RefreshRates () method                                   |
//+------------------------------------------------------------------+
void TrailingStop(const ulong ticket,const double trailing,const double step)
  {
   if(m_position.PositionType()==POSITION_TYPE_BUY)
     {
      //--- when the position still does not have StopLoss
      if(m_position.StopLoss()==0)
        {
         //--- while StopLoss is equal 0.0, we don't consider TrailingStep
         if(m_symbol.Bid()-ExtTrailingStop>m_position.PriceOpen())
           {
            //--- modification of a position
            m_trade.PositionModify(m_position.Ticket(),m_position.PriceOpen(),m_position.TakeProfit());
           }
        }
      //--- when the position already has StopLoss
      else
        {
         //--- now TrailingStep needs to be considered
         if(m_symbol.Bid()-ExtTrailingStop-ExtTrailingStep>m_position.StopLoss())
           {
            //--- modification of a position
            m_trade.PositionModify(m_position.Ticket(),
                                   m_symbol.NormalizePrice(m_symbol.Bid()-ExtTrailingStop),m_position.TakeProfit());
           }
        }
     }

   if(m_position.PositionType()==POSITION_TYPE_SELL)
     {
      //--- when the position still does not have StopLoss
      if(m_position.StopLoss()==0)
        {
         //--- while StopLoss is equal 0.0, we don't consider TrailingStep
         if(m_symbol.Ask()+ExtTrailingStop<m_position.PriceOpen())
           {
            //--- modification of a position
            m_trade.PositionModify(m_position.Ticket(),m_position.PriceOpen(),m_position.TakeProfit());
           }
        }
      //--- when the position already has StopLoss
      else
        {
         //--- now TrailingStep needs to be considered
         if(m_symbol.Ask()+ExtTrailingStop+ExtTrailingStep<m_position.StopLoss())
           {
            //--- modification of a position
            m_trade.PositionModify(m_position.Ticket(),
                                   m_symbol.NormalizePrice(m_symbol.Ask()+ExtTrailingStop),m_position.TakeProfit());
           }
        }
     }
  }
//+------------------------------------------------------------------+
