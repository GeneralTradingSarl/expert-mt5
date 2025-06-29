//+------------------------------------------------------------------+
//|                               Sidus(barabashkakvn's edition).mq5 |
//|                                     Copyright © 2010, Dm_Michael |
//|                                                   mhs_86@mail.ru |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2010, Dm_Michael"
#property link      "mhs_86@mail.ru"
#property version   "1.002"
//---
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
//--- input parameters
input double   InpLots           = 0.1;      // Lots
input ushort   InpOffset         = 3;        // Offset (SL Buy: Low#1-Offset; SL Sell: High#1+Offset) (in pips)
input ushort   InpTakeProfit     = 75;       // Take Profit (in pips)
input ushort   InpTrailingStop   = 5;        // Trailing Stop (in pips)
input ushort   InpTrailingStep   = 15;       // Trailing Step (in pips)
input double   InpDelta          = 0.00003;  // Delta between Alligator lines (#1 - #2)
input bool     InpOpposite       = false;    // Closing Opposite Positions
//--- Alligator
input int                  Inp_jaw_period       = 13;          // Alligator: period of the Jaw line
input int                  Inp_jaw_shift        = 8;           // Alligator: shift of the Jaw line
input int                  Inp_teeth_period     = 8;           // Alligator: period of the Teeth line
input int                  Inp_teeth_shift      = 5;           // Alligator: shift of the Teeth line
input int                  Inp_lips_period      = 5;           // Alligator: period of the Lips line
input int                  Inp_lips_shift       = 3;           // Alligator: shift of the Lips line
input ENUM_MA_METHOD       Inp_MA_method        = MODE_SMMA;   // Alligator: method of averaging
input ENUM_APPLIED_PRICE   Inp_applied_price    = PRICE_MEDIAN;// Alligator: type of price
//--- RSI
input int                  Inp_RSI_ma_period    = 14;          // RSI: period of averaging
input ENUM_APPLIED_PRICE   Inp_RSI_applied_price= PRICE_CLOSE; // RSI: type of price
input ulong                m_magic              = 118623120;   // magic number
//---
ulong          m_slippage=10;                // slippage

double         ExtOffset=0.0;
double         ExtTakeProfit=0.0;
double         ExtTrailingStop=0.0;
double         ExtTrailingStep=0.0;

int            handle_iAlligator;            // variable for storing the handle of the iAlligator indicator 
int            handle_iRSI;                  // variable for storing the handle of the iRSI indicator

double         m_adjusted_point;             // point value adjusted for 3 or 5 points
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpTrailingStop!=0 && InpTrailingStep==0)
     {
      string text=(TerminalInfoString(TERMINAL_LANGUAGE)=="Russian")?
                  "Трейлинг невозможен: параметр \"Trailing Step\" равен нулю!":
                  "Trailing is not possible: parameter \"Trailing Step\" is zero!";
      Alert(__FUNCTION__," ERROR! ",text);
      return(INIT_PARAMETERS_INCORRECT);
     }
//---
   if(!m_symbol.Name(Symbol())) // sets symbol name
      return(INIT_FAILED);
   RefreshRates();

   string err_text="";
   if(!CheckVolumeValue(InpLots,err_text))
     {
      Print(__FUNCTION__,", ERROR: ",err_text);
      return(INIT_PARAMETERS_INCORRECT);
     }
//---
   m_trade.SetExpertMagicNumber(m_magic);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(m_symbol.Name());
   m_trade.SetDeviationInPoints(m_slippage);
//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=m_symbol.Point()*digits_adjust;

   ExtOffset      = InpOffset    * m_adjusted_point;
   ExtTakeProfit  = InpTakeProfit* m_adjusted_point;
//--- create handle of the indicator iAlligator
   handle_iAlligator=iAlligator(m_symbol.Name(),Period(),
                                Inp_jaw_period,Inp_jaw_shift,
                                Inp_teeth_period,Inp_teeth_shift,
                                Inp_lips_period,Inp_lips_shift,
                                Inp_MA_method,Inp_applied_price);
//--- if the handle is not created 
   if(handle_iAlligator==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code 
      PrintFormat("Failed to create handle of the iAlligator indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(Period()),
                  GetLastError());
      //--- the indicator is stopped early 
      return(INIT_FAILED);
     }
//--- create handle of the indicator iRSI
   handle_iRSI=iRSI(m_symbol.Name(),Period(),Inp_RSI_ma_period,Inp_RSI_applied_price);
//--- if the handle is not created 
   if(handle_iRSI==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code 
      PrintFormat("Failed to create handle of the iRSI indicator for the symbol %s/%s, error code %d",
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
   Trailing();
//--- we work only at the time of the birth of new bar
   static datetime PrevBars=0;
   datetime time_0=iTime(m_symbol.Name(),Period(),0);
   if(time_0==PrevBars)
      return;
   PrevBars=time_0;

   double Jaw[];
   ArraySetAsSeries(Jaw,true);
   if(!iAlligatorGetArray(GATORJAW_LINE,0,3,Jaw))
     {
      PrevBars=0;
      return;
     }
   double diff_Jaw=Jaw[1]-Jaw[2];
//---
   double Teeth[];
   ArraySetAsSeries(Teeth,true);
   if(!iAlligatorGetArray(GATORTEETH_LINE,0,3,Teeth))
     {
      PrevBars=0;
      return;
     }
   double diff_Teeth=Teeth[1]-Teeth[2];
//---
   double Lips[];
   ArraySetAsSeries(Lips,true);
   if(!iAlligatorGetArray(GATORLIPS_LINE,0,3,Lips))
     {
      PrevBars=0;
      return;
     }
   double diff_Lips=Lips[1]-Lips[2];
//---
   double Rsi[];
   ArraySetAsSeries(Rsi,true);
   if(!iRSIGetArray(0,3,Rsi))
     {
      PrevBars=0;
      return;
      double dif_Rsi=Rsi[1]-Rsi[2];
      //---
/*  Comment("Diff Jaw    = ",DoubleToString(diff_Jaw,m_symbol.Digits()),
           ", Jaw #1    = ",DoubleToString(Jaw[1],m_symbol.Digits()),
           ", Jaw #2    = ",DoubleToString(Jaw[2],m_symbol.Digits()),"\n",
           "Diff Teeth  = ",DoubleToString(diff_Teeth,m_symbol.Digits()),
           ", Teeth #1  = ",DoubleToString(Teeth[1],m_symbol.Digits()),
           ", Teeth #2  = ",DoubleToString(Teeth[2],m_symbol.Digits()),"\n",
           "Diff Lips   = ",DoubleToString(diff_Lips,m_symbol.Digits()),
           ", Lips #1   = ",DoubleToString(Lips[1],m_symbol.Digits()),
           ", Lips #2   = ",DoubleToString(Lips[2],m_symbol.Digits()));*/
      //--- open Buy
      if(Rsi[2]<50.0 && Rsi[1]>50.0)
        {
         if(diff_Jaw>InpDelta && diff_Teeth>InpDelta && diff_Lips>InpDelta)
           {
            double low_1=iLow(m_symbol.Name(),Period(),1);
            if(!RefreshRates() || low_1==0.0)
              {
               PrevBars=0;
               return;
              }
            double sl=low_1-ExtOffset;
            if(sl>=m_symbol.Bid()) // incident: the position isn't opened yet, and has to be already closed
              {
               PrevBars=0;
               return;
              }
            double tp=(InpTakeProfit==0)?0.0:m_symbol.Ask()+ExtTakeProfit;
            OpenBuy(sl,tp);
            if(InpOpposite)
               ClosePositions(POSITION_TYPE_SELL);
           }
        }
      //--- open Sell
      if(Rsi[2]>50 && Rsi[1]<50)
        {
         if(diff_Jaw<InpDelta && diff_Teeth<InpDelta && diff_Lips<InpDelta)
           {
            double high_1=iHigh(m_symbol.Name(),Period(),1);
            if(!RefreshRates() || high_1==0.0)
              {
               PrevBars=0;
               return;
              }
            double sl=high_1+ExtOffset;
            if(sl<=m_symbol.Ask()) // incident: the position isn't opened yet, and has to be already closed
              {
               PrevBars=0;
               return;
              }
            double tp=(InpTakeProfit==0)?0.0:m_symbol.Bid()-ExtTakeProfit;
            OpenSell(sl,tp);
            if(InpOpposite)
               ClosePositions(POSITION_TYPE_BUY);
           }
        }
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
//| Check the correctness of the position volume                     |
//+------------------------------------------------------------------+
bool CheckVolumeValue(double volume,string &error_description)
  {
//--- minimal allowed volume for trade operations
   double min_volume=m_symbol.LotsMin();
   if(volume<min_volume)
     {
      if(TerminalInfoString(TERMINAL_LANGUAGE)=="Russian")
         error_description=StringFormat("Объем меньше минимально допустимого SYMBOL_VOLUME_MIN=%.2f",min_volume);
      else
         error_description=StringFormat("Volume is less than the minimal allowed SYMBOL_VOLUME_MIN=%.2f",min_volume);
      return(false);
     }
//--- maximal allowed volume of trade operations
   double max_volume=m_symbol.LotsMax();
   if(volume>max_volume)
     {
      if(TerminalInfoString(TERMINAL_LANGUAGE)=="Russian")
         error_description=StringFormat("Объем больше максимально допустимого SYMBOL_VOLUME_MAX=%.2f",max_volume);
      else
         error_description=StringFormat("Volume is greater than the maximal allowed SYMBOL_VOLUME_MAX=%.2f",max_volume);
      return(false);
     }
//--- get minimal step of volume changing
   double volume_step=m_symbol.LotsStep();
   int ratio=(int)MathRound(volume/volume_step);
   if(MathAbs(ratio*volume_step-volume)>0.0000001)
     {
      if(TerminalInfoString(TERMINAL_LANGUAGE)=="Russian")
         error_description=StringFormat("Объем не кратен минимальному шагу SYMBOL_VOLUME_STEP=%.2f, ближайший правильный объем %.2f",
                                        volume_step,ratio*volume_step);
      else
         error_description=StringFormat("Volume is not a multiple of the minimal step SYMBOL_VOLUME_STEP=%.2f, the closest correct volume is %.2f",
                                        volume_step,ratio*volume_step);
      return(false);
     }
   error_description="Correct volume value";
   return(true);
  }
//+------------------------------------------------------------------+
//| Get value of buffers for the iAlligator                          |
//|  the buffer numbers are the following:                           |
//|   0 - GATORJAW_LINE, 1 - GATORTEETH_LINE, 2 - GATORLIPS_LINE     |
//+------------------------------------------------------------------+
double iAlligatorGetArray(const int buffer,const int start_pos,const int count,double &arr_buffer[])
  {
//---
   bool result=true;
   if(!ArrayIsDynamic(arr_buffer))
     {
      Print("This a no dynamic array!");
      return(false);
     }
   ArrayFree(arr_buffer);
//--- reset error code 
   ResetLastError();
//--- fill a part of the iStochasticBuffer array with values from the indicator buffer that has 0 index 
   int copied=CopyBuffer(handle_iAlligator,buffer,start_pos,count,arr_buffer);
   if(copied!=count)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iAlligator indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(false);
     }
   return(result);
  }
//+------------------------------------------------------------------+
//| Get value of buffers for the iRSI in the array                   |
//+------------------------------------------------------------------+
bool iRSIGetArray(const int start_pos,const int count,double &arr_buffer[])
  {
//---
   bool result=true;
   if(!ArrayIsDynamic(arr_buffer))
     {
      Print("This a no dynamic array!");
      return(false);
     }
   ArrayFree(arr_buffer);
   int       buffer_num=0;          // indicator buffer number 
//--- reset error code 
   ResetLastError();
//--- fill a part of the iRSIBuffer array with values from the indicator buffer
   int copied=CopyBuffer(handle_iRSI,buffer_num,start_pos,count,arr_buffer);
   if(copied!=count)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iRSI indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(false);
     }
//---
   return(result);
  }
//+------------------------------------------------------------------+
//| Open Buy position                                                |
//+------------------------------------------------------------------+
void OpenBuy(double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),InpLots,m_symbol.Ask(),ORDER_TYPE_BUY);

   if(check_volume_lot!=0.0)
     {
      if(check_volume_lot>=InpLots)
        {
         if(m_trade.Buy(InpLots,m_symbol.Name(),m_symbol.Ask(),sl,tp))
           {
            if(m_trade.ResultDeal()==0)
              {
               Print(__FUNCTION__,", #1 Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResultTrade(m_trade,m_symbol);
              }
            else
              {
               Print(__FUNCTION__,", #2 Buy -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResultTrade(m_trade,m_symbol);
              }
           }
         else
           {
            Print(__FUNCTION__,", #3 Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResultTrade(m_trade,m_symbol);
           }
        }
      else
        {
         Print(__FUNCTION__,", ERROR: method CheckVolume (",DoubleToString(check_volume_lot,2),") ",
               "< Lots (",DoubleToString(InpLots,2),")");
         return;
        }
     }
   else
     {
      Print(__FUNCTION__,", ERROR: method CheckVolume returned the value of \"0.0\"");
      return;
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
   double check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),InpLots,m_symbol.Bid(),ORDER_TYPE_SELL);

   if(check_volume_lot!=0.0)
     {
      if(check_volume_lot>=InpLots)
        {
         if(m_trade.Sell(InpLots,m_symbol.Name(),m_symbol.Bid(),sl,tp))
           {
            if(m_trade.ResultDeal()==0)
              {
               Print(__FUNCTION__,", #1 Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResultTrade(m_trade,m_symbol);
              }
            else
              {
               Print(__FUNCTION__,", #2 Sell -> true. Result Retcode: ",m_trade.ResultRetcode(),
                     ", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResultTrade(m_trade,m_symbol);
              }
           }
         else
           {
            Print(__FUNCTION__,", #3 Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResultTrade(m_trade,m_symbol);
           }
        }
      else
        {
         Print(__FUNCTION__,", ERROR: method CheckVolume (",DoubleToString(check_volume_lot,2),") ",
               "< Lots (",DoubleToString(InpLots,2),")");
         return;
        }
     }
   else
     {
      Print(__FUNCTION__,", ERROR: method CheckVolume returned the value of \"0.0\"");
      return;
     }
//---
  }
//+------------------------------------------------------------------+
//| Print CTrade result                                              |
//+------------------------------------------------------------------+
void PrintResultTrade(CTrade &trade,CSymbolInfo &symbol)
  {
   Print("File: ",__FILE__,", symbol: ",m_symbol.Name());
   Print("Code of request result: "+IntegerToString(trade.ResultRetcode()));
   Print("code of request result as a string: "+trade.ResultRetcodeDescription());
   Print("Deal ticket: "+IntegerToString(trade.ResultDeal()));
   Print("Order ticket: "+IntegerToString(trade.ResultOrder()));
   Print("Volume of deal or order: "+DoubleToString(trade.ResultVolume(),2));
   Print("Price, confirmed by broker: "+DoubleToString(trade.ResultPrice(),symbol.Digits()));
   Print("Current bid price: "+DoubleToString(symbol.Bid(),symbol.Digits())+" (the requote): "+DoubleToString(trade.ResultBid(),symbol.Digits()));
   Print("Current ask price: "+DoubleToString(symbol.Ask(),symbol.Digits())+" (the requote): "+DoubleToString(trade.ResultAsk(),symbol.Digits()));
   Print("Broker comment: "+trade.ResultComment());
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
//| Trailing                                                         |
//+------------------------------------------------------------------+
void Trailing()
  {
   if(InpTrailingStop==0)
      return;
   for(int i=PositionsTotal()-1;i>=0;i--) // returns the number of open positions
      if(m_position.SelectByIndex(i))
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
           {
            if(m_position.PositionType()==POSITION_TYPE_BUY)
              {
               if(m_position.PriceCurrent()-m_position.PriceOpen()>ExtTrailingStop+ExtTrailingStep)
                  if(m_position.StopLoss()<m_position.PriceCurrent()-(ExtTrailingStop+ExtTrailingStep))
                    {
                     if(!m_trade.PositionModify(m_position.Ticket(),
                        m_symbol.NormalizePrice(m_position.PriceCurrent()-ExtTrailingStop),
                        m_position.TakeProfit()))
                        Print("Modify ",m_position.Ticket(),
                              " Position -> false. Result Retcode: ",m_trade.ResultRetcode(),
                              ", description of result: ",m_trade.ResultRetcodeDescription());
                     RefreshRates();
                     m_position.SelectByIndex(i);
                     PrintResultModify(m_trade,m_symbol,m_position);
                     continue;
                    }
              }
            else
              {
               if(m_position.PriceOpen()-m_position.PriceCurrent()>ExtTrailingStop+ExtTrailingStep)
                  if((m_position.StopLoss()>(m_position.PriceCurrent()+(ExtTrailingStop+ExtTrailingStep))) || 
                     (m_position.StopLoss()==0))
                    {
                     if(!m_trade.PositionModify(m_position.Ticket(),
                        m_symbol.NormalizePrice(m_position.PriceCurrent()+ExtTrailingStop),
                        m_position.TakeProfit()))
                        Print("Modify ",m_position.Ticket(),
                              " Position -> false. Result Retcode: ",m_trade.ResultRetcode(),
                              ", description of result: ",m_trade.ResultRetcodeDescription());
                     RefreshRates();
                     m_position.SelectByIndex(i);
                     PrintResultModify(m_trade,m_symbol,m_position);
                    }
              }

           }
  }
//+------------------------------------------------------------------+
//| Print CTrade result                                              |
//+------------------------------------------------------------------+
void PrintResultModify(CTrade &trade,CSymbolInfo &symbol,CPositionInfo &position)
  {
   Print("File: ",__FILE__,", symbol: ",m_symbol.Name());
   Print("Code of request result: "+IntegerToString(trade.ResultRetcode()));
   Print("code of request result as a string: "+trade.ResultRetcodeDescription());
   Print("Deal ticket: "+IntegerToString(trade.ResultDeal()));
   Print("Order ticket: "+IntegerToString(trade.ResultOrder()));
   Print("Volume of deal or order: "+DoubleToString(trade.ResultVolume(),2));
   Print("Price, confirmed by broker: "+DoubleToString(trade.ResultPrice(),symbol.Digits()));
   Print("Current bid price: "+DoubleToString(symbol.Bid(),symbol.Digits())+" (the requote): "+DoubleToString(trade.ResultBid(),symbol.Digits()));
   Print("Current ask price: "+DoubleToString(symbol.Ask(),symbol.Digits())+" (the requote): "+DoubleToString(trade.ResultAsk(),symbol.Digits()));
   Print("Broker comment: "+trade.ResultComment());
   Print("Price of position opening: "+DoubleToString(position.PriceOpen(),symbol.Digits()));
   Print("Price of position's Stop Loss: "+DoubleToString(position.StopLoss(),symbol.Digits()));
   Print("Price of position's Take Profit: "+DoubleToString(position.TakeProfit(),symbol.Digits()));
   Print("Current price by position: "+DoubleToString(position.PriceCurrent(),symbol.Digits()));
  }
//+------------------------------------------------------------------+
