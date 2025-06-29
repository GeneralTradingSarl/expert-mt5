//+------------------------------------------------------------------+
//|                         JS_SISTEM_2(barabashkakvn's edition).mq5 |
//+------------------------------------------------------------------+
#property version   "1.001"
//---
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
#include <Expert\Money\MoneyFixedMargin.mqh>
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
CAccountInfo   m_account;                    // account info wrapper
CMoneyFixedMargin m_money;
//--- input parameters
sinput string  _0_                  = "Trade setting";            // Trade setting
input double   InpMinBalance        = 100.0;                      // The minimum balanse. If less - then close the expert advisor
input double   InpLots              = 0.01;                       // Lots (if "Lots" <=0.0 -> then the "Risk" parameter is used)
input ushort   InpStopLoss          = 35;                         // Stop Loss (in pips)
input ushort   InpTakeProfit        = 40;                         // Take Profit (in pips)
input double   Risk                 = 5;                          // Risk in percent for a deal from a free margin (if "Lots" <=0.0)
input int      Inpvolatility        = 15;                         // Volatility (in bars)
input ulong    m_magic              = 137574252;                  // magic number
sinput string  _1_                  = "Moving Average setting";   // Moving Average setting
input ushort   InpMinDifference     = 28;                         // Minimum difference between Moving Average indicators
input int      MA_1_period          = 55;                         // Moving Average #1: averaging period 
input int      MA_2_period          = 89;                         // Moving Average #2: averaging period 
input int      MA_3_period          = 144;                        // Moving Average #3: averaging period 
sinput string  _2_                  = "OsMA setting";             // OsMA setting
input int      OsMA_fast_ema_period = 13;                         // OsMA: period for Fast Moving Average 
input int      OsMA_slow_ema_period = 55;                         // OsMA: period for Slow Moving Average 
input int      OsMA_signal_period   = 21;                         // OsMA: averaging period for their difference 
sinput string  _3_                  = "RVI setting";              // RVI setting
input int      RVI_ma_period        = 44;                         // RVI: averaging period 
input double   RVI_max              = 0.04;                       // RVI max value 
input double   RVI_min              = -0.04;                      // RVI min value
sinput string  _4_                  = "Trailingon shadows";       // Trailing on shadows of bars
input bool     InpTrailingShadows   = true;                       // Trailing Shadows
input ENUM_TIMEFRAMES InpTSTimeFrames=PERIOD_M5;                  // Timeframe
input ushort   InpIndentSL          = 1;                          // Indent from the shadow of the bar on which the stop loss is placed
//---
ulong          m_slippage=30;                // slippage

double         ExtStopLoss=0.0;
double         ExtTakeProfit=0.0;
double         ExtMinDifference=0.0;
double         ExtIndentSL=0.0;

int    handle_iMA_1;                         // variable for storing the handle of the iMA indicator 
int    handle_iMA_2;                         // variable for storing the handle of the iMA indicator 
int    handle_iMA_3;                         // variable for storing the handle of the iMA indicator 
int    handle_iOsMA;                         // variable for storing the handle of the iOsMA indicator 
int    handle_iRVI;                          // variable for storing the handle of the iRVI indicator 

double         m_adjusted_point;             // point value adjusted for 3 or 5 points
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   if(!m_symbol.Name(Symbol())) // sets symbol name
      return(INIT_FAILED);
   RefreshRates();

   string err_text="";
   if(InpLots>0.0)
      if(!CheckVolumeValue(InpLots,err_text))
        {
         Print(err_text);
         return(INIT_PARAMETERS_INCORRECT);
        }
//---
   m_trade.SetExpertMagicNumber(m_magic);
//---
   if(IsFillingTypeAllowed(SYMBOL_FILLING_FOK))
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if(IsFillingTypeAllowed(SYMBOL_FILLING_IOC))
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

   ExtStopLoss=InpStopLoss*m_adjusted_point;
   ExtTakeProfit=InpTakeProfit*m_adjusted_point;
   ExtMinDifference=InpMinDifference*m_adjusted_point;
   ExtIndentSL=InpIndentSL*m_adjusted_point;
//---
   if(InpLots<=0.0)
     {
      if(!m_money.Init(GetPointer(m_symbol),Period(),m_symbol.Point()*digits_adjust))
         return(INIT_FAILED);
      m_money.Percent(Risk);
     }
//--- create handle of the indicator iMA
   handle_iMA_1=iMA(m_symbol.Name(),Period(),MA_1_period,0,MODE_EMA,PRICE_CLOSE);
//--- if the handle is not created 
   if(handle_iMA_1==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code 
      PrintFormat("Failed to create handle of the iMA indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early 
      return(INIT_FAILED);
     }
//--- create handle of the indicator iMA
   handle_iMA_2=iMA(m_symbol.Name(),Period(),MA_2_period,0,MODE_EMA,PRICE_CLOSE);
//--- if the handle is not created 
   if(handle_iMA_2==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code 
      PrintFormat("Failed to create handle of the iMA indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early 
      return(INIT_FAILED);
     }
//--- create handle of the indicator iMA
   handle_iMA_3=iMA(m_symbol.Name(),Period(),MA_3_period,0,MODE_EMA,PRICE_CLOSE);
//--- if the handle is not created 
   if(handle_iMA_3==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code 
      PrintFormat("Failed to create handle of the iMA indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early 
      return(INIT_FAILED);
     }
//--- create handle of the indicator iOsMA
   handle_iOsMA=iOsMA(m_symbol.Name(),Period(),OsMA_fast_ema_period,OsMA_slow_ema_period,OsMA_signal_period,PRICE_CLOSE);
//--- if the handle is not created 
   if(handle_iOsMA==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code 
      PrintFormat("Failed to create a handle of iOsMA for the pair %s/%s, error code is %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early 
      return(INIT_FAILED);
     }
//--- create handle of the indicator iRVI  
   handle_iRVI=iRVI(m_symbol.Name(),Period(),RVI_ma_period);
//--- if the handle is not created 
   if(handle_iRVI==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code 
      PrintFormat("Failed to create handle of the iRVI indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early 
      return(INIT_FAILED);
     }
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
   if(!RefreshRates())
     {
      PrevBars=iTime(1);
      return;
     }
//---
   if(m_account.Balance()<InpMinBalance) // the money ran out
      return;
//---
   double arr_high[];
   double arr_low[];
   ArraySetAsSeries(arr_high,true);
   ArraySetAsSeries(arr_low,true);
   int copied=CopyHigh(m_symbol.Name(),InpTSTimeFrames,1,Inpvolatility,arr_high);
   if(copied!=Inpvolatility)
      return;
   copied=CopyLow(m_symbol.Name(),InpTSTimeFrames,1,Inpvolatility,arr_low);
   if(copied!=Inpvolatility)
      return;

   if(InpTrailingShadows)
      if(RefreshRates())
         TrailPositions(arr_high,arr_low);
//---
   double ima_a   = iMAGet(handle_iMA_1,1);
   double ima_b   = iMAGet(handle_iMA_2,1);
   double ima_c   = iMAGet(handle_iMA_3,1);
   double OsMA1   = iOsMAGet(1);
   double RVI_M   = iRVIGet(MAIN_LINE,1);
   double RVI_S   = iRVIGet(SIGNAL_LINE,1);

   double difference_1  = ima_a-ima_c;
   double difference_2  = ima_c-ima_a;
//---
   double Rsmax = arr_high[ArrayMaximum(arr_high,0,WHOLE_ARRAY)];
   double Rsmin = arr_low[ArrayMinimum(arr_low,0,WHOLE_ARRAY)];
   double AvgRange=(Rsmax-Rsmin)/m_adjusted_point;
   string text="Volatility:  "+DoubleToString(AvgRange,0)+" pips";
   Comment(text);
//---
   int count_buys=0;
   int count_sells=0;
   CalculatePositions(count_buys,count_sells);

   if(count_buys==0)
      if(OsMA1>0.0 && RVI_M>RVI_S && RVI_S>=RVI_max && ima_a>ima_b && ima_b>ima_c && difference_1<ExtMinDifference)
        {
         ClosePositions(POSITION_TYPE_SELL);
         double sl=(InpStopLoss==0)?0.0:m_symbol.Ask()-ExtStopLoss;
         double tp=(InpTakeProfit==0)?0.0:m_symbol.Ask()+ExtTakeProfit;
         OpenBuy(sl,tp);
         return;
        }
//---
   if(count_sells==0)
      if(OsMA1<0.0 && RVI_M<RVI_S && RVI_S<=RVI_min && ima_a<ima_b && ima_b<ima_c && difference_2<ExtMinDifference)
        {
         ClosePositions(POSITION_TYPE_BUY);
         double sl=(InpStopLoss==0)?0.0:m_symbol.Bid()+ExtStopLoss;
         double tp=(InpTakeProfit==0)?0.0:m_symbol.Bid()-ExtTakeProfit;
         OpenSell(sl,tp);
         return;
        }
  }
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
//---

  }
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates(void)
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
     {
      Print("RefreshRates error");
      return(false);
     }
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
   double min_volume=m_symbol.LotsMin();
   if(volume<min_volume)
     {
      error_description=StringFormat("Volume is less than the minimal allowed SYMBOL_VOLUME_MIN=%.2f",min_volume);
      return(false);
     }
//--- maximal allowed volume of trade operations
   double max_volume=m_symbol.LotsMax();
   if(volume>max_volume)
     {
      error_description=StringFormat("Volume is greater than the maximal allowed SYMBOL_VOLUME_MAX=%.2f",max_volume);
      return(false);
     }
//--- get minimal step of volume changing
   double volume_step=m_symbol.LotsStep();
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
bool IsFillingTypeAllowed(int fill_type)
  {
//--- Obtain the value of the property that describes allowed filling modes 
   int filling=m_symbol.TradeFillFlags();
//--- Return true, if mode fill_type is allowed 
   return((filling & fill_type)==fill_type);
  }
//+------------------------------------------------------------------+ 
//| Get Time for specified bar index                                 | 
//+------------------------------------------------------------------+ 
datetime iTime(const int index,string symbol=NULL,ENUM_TIMEFRAMES timeframe=PERIOD_CURRENT)
  {
   if(symbol==NULL)
      symbol=m_symbol.Name();
   if(timeframe==0)
      timeframe=Period();
   datetime Time[1];
   datetime time=0;
   int copied=CopyTime(symbol,timeframe,index,1,Time);
   if(copied>0)
      time=Time[0];
   return(time);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TrailPositions(double &arr_high[],double &arr_low[])
  {
   double High_lowest=0.0; // the lowest value of the array "arr_high"
   double Low_highest=0.0; // the highest value of the array "arr_low"

   for(int i=0;i<Inpvolatility;i++)
     {
      if(i==0)
        {
         High_lowest=arr_high[0];
         Low_highest=arr_low[0];
        }
      else
        {
         if(High_lowest<arr_high[i]) // the lowest value of the array "arr_high"
            High_lowest=arr_high[i];
         if(Low_highest>arr_low[i]) // the highest value of the array "arr_low"
            Low_highest=arr_low[i];
        }
     }
//---
   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of open positions
      if(m_position.SelectByIndex(i))
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
           {
            if(m_position.PositionType()==POSITION_TYPE_BUY)
              {
               double triple_spread=(m_symbol.Ask()-m_symbol.Bid())*3.0;
               double step=ExtIndentSL;
               if(m_position.PriceCurrent()-Low_highest>ExtIndentSL+triple_spread)
                  if(Low_highest-m_position.PriceOpen()>step)
                     if(Low_highest-m_position.StopLoss()>step)
                       {
                        if(!m_trade.PositionModify(m_position.Ticket(),
                           m_symbol.NormalizePrice(Low_highest),
                           m_position.TakeProfit()))
                           Print("Modify ",m_position.Ticket(),
                                 " Position -> false. Result Retcode: ",m_trade.ResultRetcode(),
                                 ", description of result: ",m_trade.ResultRetcodeDescription());
                        continue;
                       }
              }
            else
              {
               double triple_spread=(m_symbol.Ask()-m_symbol.Bid())*3.0;
               double step=ExtIndentSL;
               if(High_lowest-m_position.PriceCurrent()>ExtIndentSL+triple_spread)
                  if(m_position.PriceOpen()-High_lowest>step)
                     if(m_position.StopLoss()-High_lowest>step || m_position.StopLoss()==0.0)
                       {
                        if(!m_trade.PositionModify(m_position.Ticket(),
                           m_symbol.NormalizePrice(High_lowest),
                           m_position.TakeProfit()))
                           Print("Modify ",m_position.Ticket(),
                                 " Position -> false. Result Retcode: ",m_trade.ResultRetcode(),
                                 ", description of result: ",m_trade.ResultRetcodeDescription());
                        continue;
                       }
              }

           }
//---
  }
//+------------------------------------------------------------------+
//| Get value of buffers for the iMA                                 |
//+------------------------------------------------------------------+
double iMAGet(int handle_iMA,const int index)
  {
   double MA[1];
//--- reset error code 
   ResetLastError();
//--- fill a part of the iMABuffer array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(handle_iMA,0,index,1,MA)<0)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iMA indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(0.0);
     }
   return(MA[0]);
  }
//+------------------------------------------------------------------+
//| Get value of buffers for the iOsMA                               |
//+------------------------------------------------------------------+
double iOsMAGet(const int index)
  {
   double OsMA[1];
//--- reset error code 
   ResetLastError();
//--- fill a part of the iOsMA array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(handle_iOsMA,0,index,1,OsMA)<0)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iOsMA indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(0.0);
     }
   return(OsMA[0]);
  }
//+------------------------------------------------------------------+
//| Get value of buffers for the iRVI                                |
//|  the buffer numbers are the following:                           |
//|   0 - MAIN_LINE, 1 - SIGNAL_LINE                                 |
//+------------------------------------------------------------------+
double iRVIGet(const int buffer,const int index)
  {
   double RVI[1];
//--- reset error code 
   ResetLastError();
//--- fill a part of the iRVIr array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(handle_iRVI,buffer,index,1,RVI)<0)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iRVI indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(0.0);
     }
   return(RVI[0]);
  }
//+------------------------------------------------------------------+
//| Calculate positions Buy and Sell                                 |
//+------------------------------------------------------------------+
void CalculatePositions(int &count_buys,int &count_sells)
  {
   count_buys=0.0;
   count_sells=0.0;

   for(int i=PositionsTotal()-1;i>=0;i--)
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
           {
            if(m_position.PositionType()==POSITION_TYPE_BUY)
               count_buys++;

            if(m_position.PositionType()==POSITION_TYPE_SELL)
               count_sells++;
           }
//---
   return;
  }
//+------------------------------------------------------------------+
//| Close positions                                                  |
//+------------------------------------------------------------------+
void ClosePositions(const ENUM_POSITION_TYPE pos_type)
  {
   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of current positions
      if(m_position.SelectByIndex(i))     // selects the position by index for further access to its properties
         if(m_position.Symbol()==Symbol() && m_position.Magic()==m_magic)
            if(m_position.PositionType()==pos_type) // gets the position type
               m_trade.PositionClose(m_position.Ticket()); // close a position by the specified symbol
  }
//+------------------------------------------------------------------+
//| Open Buy position                                                |
//+------------------------------------------------------------------+
void OpenBuy(double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);

   double check_open_long_lot=0.0;
   if(InpLots<=0.0)
     {
      check_open_long_lot=m_money.CheckOpenLong(m_symbol.Ask(),sl);
      Print("sl=",DoubleToString(sl,m_symbol.Digits()),
            ", CheckOpenLong: ",DoubleToString(check_open_long_lot,2),
            ", Balance: ",    DoubleToString(m_account.Balance(),2),
            ", Equity: ",     DoubleToString(m_account.Equity(),2),
            ", FreeMargin: ", DoubleToString(m_account.FreeMargin(),2));
      if(check_open_long_lot==0.0)
         return;
     }
   else
      check_open_long_lot=InpLots;
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),check_open_long_lot,m_symbol.Ask(),ORDER_TYPE_BUY);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=check_open_long_lot)
        {
         if(m_trade.Buy(check_open_long_lot,NULL,m_symbol.Ask(),sl,tp))
           {
            if(m_trade.ResultDeal()==0)
              {
               Print("#1 Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResult(m_trade,m_symbol);
              }
            else
              {
               Print("#2 Buy -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResult(m_trade,m_symbol);
              }
           }
         else
           {
            Print("#3 Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResult(m_trade,m_symbol);
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

   double check_open_short_lot=0.0;
   if(InpLots<=0.0)
     {
      check_open_short_lot=m_money.CheckOpenShort(m_symbol.Bid(),sl);
      Print("sl=",DoubleToString(sl,m_symbol.Digits()),
            ", CheckOpenLong: ",DoubleToString(check_open_short_lot,2),
            ", Balance: ",    DoubleToString(m_account.Balance(),2),
            ", Equity: ",     DoubleToString(m_account.Equity(),2),
            ", FreeMargin: ", DoubleToString(m_account.FreeMargin(),2));
      if(check_open_short_lot==0.0)
         return;
     }
   else
      check_open_short_lot=InpLots;
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),check_open_short_lot,m_symbol.Bid(),ORDER_TYPE_SELL);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=check_open_short_lot)
        {
         if(m_trade.Sell(check_open_short_lot,NULL,m_symbol.Bid(),sl,tp))
           {
            if(m_trade.ResultDeal()==0)
              {
               Print("#1 Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResult(m_trade,m_symbol);
              }
            else
              {
               Print("#2 Sell -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResult(m_trade,m_symbol);
              }
           }
         else
           {
            Print("#3 Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResult(m_trade,m_symbol);
           }
        }
//---
  }
//+------------------------------------------------------------------+
//| Print CTrade result                                              |
//+------------------------------------------------------------------+
void PrintResult(CTrade &trade,CSymbolInfo &symbol)
  {
   Print("Code of request result: "+IntegerToString(trade.ResultRetcode()));
   Print("code of request result: "+trade.ResultRetcodeDescription());
   Print("deal ticket: "+IntegerToString(trade.ResultDeal()));
   Print("order ticket: "+IntegerToString(trade.ResultOrder()));
   Print("volume of deal or order: "+DoubleToString(trade.ResultVolume(),2));
   Print("price, confirmed by broker: "+DoubleToString(trade.ResultPrice(),symbol.Digits()));
   Print("current bid price: "+DoubleToString(trade.ResultBid(),symbol.Digits()));
   Print("current ask price: "+DoubleToString(trade.ResultAsk(),symbol.Digits()));
   Print("broker comment: "+trade.ResultComment());
   DebugBreak();
  }
//+------------------------------------------------------------------+
