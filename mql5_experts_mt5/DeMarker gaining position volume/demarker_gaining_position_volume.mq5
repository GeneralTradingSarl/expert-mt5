//+------------------------------------------------------------------+
//|                             DeMarker gaining position volume.mq5 |
//|                              Copyright © 2022, Vladimir Karputov |
//|                      https://www.mql5.com/en/users/barabashkakvn |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2022, Vladimir Karputov"
#property link      "https://www.mql5.com/en/users/barabashkakvn"
#property version   "1.003"
#property description "barabashkakvn Trading engine 4.016"
#property description "Take Profit, Stop Loss and Trailing - in Points (1.00055-1.00045=10 points)"
/*
   barabashkakvn Trading engine 4.016
*/
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Expert\Money\MoneyFixedMargin.mqh>
//---
CPositionInfo  m_position;                   // object of CPositionInfo class
CTrade         m_trade;                      // object of CTrade class
CSymbolInfo    m_symbol;                     // object of CSymbolInfo class
CAccountInfo   m_account;                    // object of CAccountInfo class
CDealInfo      m_deal;                       // object of CDealInfo class
CMoneyFixedMargin *m_money;                  // object of CMoneyFixedMargin class
//+------------------------------------------------------------------+
//| Enum Lor or Risk                                                 |
//+------------------------------------------------------------------+
enum ENUM_LOT_OR_RISK
  {
   lots_min=0, // Lots Min
   lot=1,      // Constant lot
   risk=2,     // Risk in percent for a deal (range: from 1.00 to 100.00)
  };
//+------------------------------------------------------------------+
//| Enum Bar Сurrent                                                 |
//+------------------------------------------------------------------+
enum ENUM_BAR_CURRENT
  {
   bar_0=0,    // bar #0 (at every tick)
   bar_1=1,    // bar #1 (on a new bar)
  };
//--- input parameters
input group             "Trading settings"
input ENUM_TIMEFRAMES      InpWorkingPeriod        = PERIOD_CURRENT; // Working timeframe
input group             "Position size management (lot calculation)"
input ENUM_LOT_OR_RISK     InpLotOrRisk            = risk;           // Money management lot: Lot OR Risk
input double               InpVolumeLotOrRisk      = 3.0;            // The value for "Money management"
input group             "DeMarker"
input int                  Inp_DeM_ma_period       = 14;             // DeM: averaging period
input double               Inp_DeM_LevelUp         = 0.7;            // DeM: Level UP
input double               Inp_DeM_LevelDown       = 0.3;            // DeM: Level DOWN
input ENUM_APPLIED_PRICE   Inp_DEMA_applied_price  = PRICE_CLOSE;    // DEMA: type of price
input group             "Additional features"
input bool                 InpOnlyOne              = false;          // Positions: Only one
input bool                 InpReverse              = false;          // Positions: Reverse
input bool                 InpPrintLog             = true;           // Print log
input ulong                InpDeviation            = 10;             // Deviation, in Points (1.00045-1.00055=10 points)
input ulong                InpMagic                = 241242684;      // Magic number
//---
int      handle_iDeMarker;                      // variable for storing the handle of the iDeMarker indicator

bool     m_need_close_all           = false;    // close all positions
bool     m_need_close_buy           = false;    // close all buy positions
bool     m_need_close_sell          = false;    // close all sell positions
datetime m_prev_bars                = 0;        // "0" -> D'1970.01.01 00:00';
datetime m_last_deal_buy_in         = 0;        // "0" -> D'1970.01.01 00:00';
datetime m_last_deal_sell_in        = 0;        // "0" -> D'1970.01.01 00:00';
int      m_bar_current              = 0;
bool     m_init_error               = false;    // error on InInit
//--- the tactic is this: for positions we strictly monitor the result, ***
//+------------------------------------------------------------------+
//| Structure Positions                                              |
//+------------------------------------------------------------------+
struct STRUCT_POSITION
  {
   ENUM_POSITION_TYPE pos_type;              // position type
   double            volume;                 // position volume (if "0.0" -> the lot is "Money management")
   double            lot_coefficient;        // lot coefficient
   bool              waiting_transaction;    // waiting transaction, "true" -> it's forbidden to trade, we expect a transaction
   ulong             waiting_order_ticket;   // waiting order ticket, ticket of the expected order
   bool              transaction_confirmed;  // transaction confirmed, "true" -> transaction confirmed
   //--- Constructor
                     STRUCT_POSITION()
     {
      pos_type                   = WRONG_VALUE;
      volume                     = 0.0;
      lot_coefficient            = 0.0;
      waiting_transaction        = false;
      waiting_order_ticket       = 0;
      transaction_confirmed      = false;
     }
  };
STRUCT_POSITION SPosition[];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- forced initialization of variables
   m_need_close_all           = false;    // close all positions
   m_need_close_buy           = false;    // close all buy positions
   m_need_close_sell          = false;    // close all sell positions
   m_prev_bars                = 0;        // "0" -> D'1970.01.01 00:00';
   m_last_deal_buy_in         = 0;        // "0" -> D'1970.01.01 00:00';
   m_last_deal_sell_in        = 0;        // "0" -> D'1970.01.01 00:00';
   m_bar_current              = 0;
   m_init_error               = false;    // error on InInit
//---
   if(Inp_DeM_LevelUp<=Inp_DeM_LevelDown)
     {
      string err_text=(TerminalInfoString(TERMINAL_LANGUAGE)=="Russian")?
                      "'DeM: Level UP' не может быть <= 'DeM: Level DOWN'!":
                      "'DeM: Level UP' cannot be <= 'DeM: Level DOWN'!";
      if(MQLInfoInteger(MQL_TESTER)) // when testing, we will only output to the log about incorrect input parameters
         Print(__FILE__," ",__FUNCTION__,", ERROR: ",err_text);
      else // if the Expert Advisor is run on the chart, tell the user about the error
         Alert(__FILE__," ",__FUNCTION__,", ERROR: ",err_text);
      //---
      m_init_error=true;
      return(INIT_SUCCEEDED);
     }
//---
   ResetLastError();
   if(!m_symbol.Name(Symbol())) // sets symbol name
     {
      Print(__FILE__," ",__FUNCTION__,", ERROR: CSymbolInfo.Name");
      return(INIT_FAILED);
     }
   RefreshRates();
//---
   m_trade.SetExpertMagicNumber(InpMagic);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(m_symbol.Name());
   m_trade.SetDeviationInPoints(InpDeviation);
//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
//--- check the input parameter "Lots"
   string err_text="";
   if(InpLotOrRisk==lot)
     {
      if(!CheckVolumeValue(InpVolumeLotOrRisk,err_text))
        {
         if(MQLInfoInteger(MQL_TESTER)) // when testing, we will only output to the log about incorrect input parameters
            Print(__FILE__," ",__FUNCTION__,", ERROR: ",err_text);
         else // if the Expert Advisor is run on the chart, tell the user about the error
            Alert(__FILE__," ",__FUNCTION__,", ERROR: ",err_text);
         //---
         m_init_error=true;
         return(INIT_SUCCEEDED);
        }
     }
   else
      if(InpLotOrRisk==risk)
        {
         if(m_money!=NULL)
            delete m_money;
         m_money=new CMoneyFixedMargin;
         if(m_money!=NULL)
           {
            if(InpVolumeLotOrRisk<1 || InpVolumeLotOrRisk>100)
              {
               Print(__FILE__," ",__FUNCTION__,", ERROR: ");
               Print("The value for \"Money management\" (",DoubleToString(InpVolumeLotOrRisk,2),") -> invalid parameters");
               Print("   parameter must be in the range: from 1.00 to 100.00");
               //---
               m_init_error=true;
               return(INIT_SUCCEEDED);
              }
            if(!m_money.Init(GetPointer(m_symbol),InpWorkingPeriod,m_symbol.Point()*digits_adjust))
              {
               Print(__FILE__," ",__FUNCTION__,", ERROR: CMoneyFixedMargin.Init");
               //---
               m_init_error=true;
               return(INIT_SUCCEEDED);
              }
            m_money.Percent(InpVolumeLotOrRisk);
           }
         else
           {
            Print(__FILE__," ",__FUNCTION__,", ERROR: Object CMoneyFixedMargin is NULL");
            return(INIT_FAILED);
           }
        }
//--- create handle of the indicator iDeMarker
   handle_iDeMarker=iDeMarker(m_symbol.Name(),InpWorkingPeriod,Inp_DeM_ma_period);
//--- if the handle is not created
   if(handle_iDeMarker==INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the iDeMarker indicator for the symbol %s/%s, error code %d",
                  m_symbol.Name(),
                  EnumToString(InpWorkingPeriod),
                  GetLastError());
      //--- the indicator is stopped early
      m_init_error=true;
      return(INIT_SUCCEEDED);
     }
//---
   m_bar_current=1;
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   if(m_money!=NULL)
      delete m_money;
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(m_init_error)
      return;
//---
   if(m_need_close_all)
     {
      if(IsPositionExists())
        {
         CloseAllPositions();
         return;
        }
      else
        {
         m_need_close_all=false;
         ArrayFree(SPosition);
        }
     }
   if(m_need_close_buy || m_need_close_sell)
     {
      //---
      int      count_buys           = 0;
      double   volume_buys          = 0.0;
      double   volume_biggest_buys  = 0.0;
      int      count_sells          = 0;
      double   volume_sells         = 0.0;
      double   volume_biggest_sells = 0.0;
      CalculateAllPositions(count_buys,volume_buys,volume_biggest_buys,
                            count_sells,volume_sells,volume_biggest_sells,
                            false);
      //---
      if(m_need_close_buy)
        {
         if(count_buys>0)
           {
            ClosePositions(POSITION_TYPE_BUY);
            return;
           }
         else
            m_need_close_buy=false;
        }
      if(m_need_close_sell)
        {
         if(count_sells>0)
           {
            ClosePositions(POSITION_TYPE_SELL);
            return;
           }
         else
            m_need_close_sell=false;
        }
     }
//---
   int size_need_position=ArraySize(SPosition);
   if(size_need_position>0)
     {
      for(int i=size_need_position-1; i>=0; i--)
        {
         if(SPosition[i].waiting_transaction)
           {
            if(!SPosition[i].transaction_confirmed)
              {
               if(InpPrintLog)
                  Print(__FILE__," ",__FUNCTION__,", OK: ","transaction_confirmed: ",SPosition[i].transaction_confirmed);
               return;
              }
            else
               if(SPosition[i].transaction_confirmed)
                 {
                  ArrayRemove(SPosition,i,1);
                  return;
                 }
           }
         //---
         int      count_buys           = 0;
         double   volume_buys          = 0.0;
         double   volume_biggest_buys  = 0.0;
         int      count_sells          = 0;
         double   volume_sells         = 0.0;
         double   volume_biggest_sells = 0.0;
         if(InpOnlyOne)
           {
            CalculateAllPositions(count_buys,volume_buys,volume_biggest_buys,
                                  count_sells,volume_sells,volume_biggest_sells,
                                  false);
           }
         //---
         if(SPosition[i].pos_type==POSITION_TYPE_BUY)
           {
            if(InpOnlyOne)
              {
               if(count_buys+count_sells==0)
                 {
                  SPosition[i].waiting_transaction=true;
                  OpenPosition(i);
                  return;
                 }
               else
                 {
                  ArrayRemove(SPosition,i,1);
                  return;
                 }
              }
            SPosition[i].waiting_transaction=true;
            OpenPosition(i);
            return;
           }
         if(SPosition[i].pos_type==POSITION_TYPE_SELL)
           {
            if(InpOnlyOne)
              {
               if(count_buys+count_sells==0)
                 {
                  SPosition[i].waiting_transaction=true;
                  OpenPosition(i);
                  return;
                 }
               else
                 {
                  ArrayRemove(SPosition,i,1);
                  return;
                 }
              }
            SPosition[i].waiting_transaction=true;
            OpenPosition(i);
            return;
           }
        }
     }
//--- we work only at the time of the birth of new bar
   datetime time_0=iTime(m_symbol.Name(),InpWorkingPeriod,0);
   if(time_0==m_prev_bars)
      return;
   m_prev_bars=time_0;
// search for trading signals only at the time of the birth of new bar
   if(!RefreshRates())
     {
      m_prev_bars=0;
      return;
     }
//--- search for trading signals
   if(!SearchTradingSignals())
     {
      m_prev_bars=0;
      return;
     }
//---
  }
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
//--- get transaction type as enumeration value
   ENUM_TRADE_TRANSACTION_TYPE type=trans.type;
//--- if transaction is result of addition of the transaction in history
   if(type==TRADE_TRANSACTION_DEAL_ADD)
     {
      ResetLastError();
      if(HistoryDealSelect(trans.deal))
         m_deal.Ticket(trans.deal);
      else
        {
         Print(__FILE__," ",__FUNCTION__,", ERROR: ","HistoryDealSelect(",trans.deal,") error: ",GetLastError());
         return;
        }
      if(m_deal.Symbol()==m_symbol.Name() && m_deal.Magic()==InpMagic)
        {
         ENUM_DEAL_TYPE deal_type   = m_deal.DealType();
         ENUM_DEAL_ENTRY deal_entry = m_deal.Entry();
         if(deal_type==DEAL_TYPE_BUY || deal_type==DEAL_TYPE_SELL)
           {
            if(deal_entry==DEAL_ENTRY_IN || deal_entry==DEAL_ENTRY_INOUT)
              {
               if(deal_type==DEAL_TYPE_BUY)
                  m_last_deal_buy_in=iTime(m_symbol.Name(),InpWorkingPeriod,0);
               else
                  m_last_deal_sell_in=iTime(m_symbol.Name(),InpWorkingPeriod,0);
              }
            int size_need_position=ArraySize(SPosition);
            if(size_need_position>0)
              {
               for(int i=0; i<size_need_position; i++)
                 {
                  if(SPosition[i].waiting_transaction)
                     if(SPosition[i].waiting_order_ticket==m_deal.Order())
                       {
                        Print(__FUNCTION__," Transaction confirmed");
                        SPosition[i].transaction_confirmed=true;
                        break;
                       }
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates()
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
     {
      Print(__FILE__," ",__FUNCTION__,", ERROR: ","RefreshRates error");
      return(false);
     }
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
     {
      Print(__FILE__," ",__FUNCTION__,", ERROR: ","Ask == 0.0 OR Bid == 0.0");
      return(false);
     }
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
//---
   return(true);
  }
//+------------------------------------------------------------------+
//| Lot Check                                                        |
//+------------------------------------------------------------------+
double LotCheck(double lots,CSymbolInfo &symbol)
  {
//--- calculate maximum volume
   double volume=NormalizeDouble(lots,2);
   double stepvol=symbol.LotsStep();
   if(stepvol>0.0)
      volume=stepvol*MathFloor(volume/stepvol);
//---
   double minvol=symbol.LotsMin();
   if(volume<minvol)
      volume=0.0;
//---
   double maxvol=symbol.LotsMax();
   if(volume>maxvol)
      volume=maxvol;
//---
   return(volume);
  }

//+------------------------------------------------------------------+
//| Open position                                                    |
//+------------------------------------------------------------------+
void OpenPosition(const int index)
  {
   if(!RefreshRates())
      return;
//--- buy
   if(SPosition[index].pos_type==POSITION_TYPE_BUY)
     {
      OpenBuy(index);
      return;
     }
//--- sell
   if(SPosition[index].pos_type==POSITION_TYPE_SELL)
     {
      OpenSell(index);
      return;
     }
  }
//+------------------------------------------------------------------+
//| Open Buy position                                                |
//+------------------------------------------------------------------+
void OpenBuy(const int index)
  {
   double sl=0.0;
   double tp=0.0;
   double long_lot=0.0;
   if(SPosition[index].volume>0.0)
      long_lot=SPosition[index].volume;
   else
     {
      if(InpLotOrRisk==risk)
        {
         long_lot=m_money.CheckOpenLong(m_symbol.Ask(),sl);
         if(InpPrintLog)
            Print(__FILE__," ",__FUNCTION__,", OK: ",
                  "CheckOpenLong (price(",DoubleToString(m_symbol.Ask(),m_symbol.Digits()),"),sl(",DoubleToString(sl,m_symbol.Digits()),"))",
                  " -> Lot: ",DoubleToString(long_lot,2),
                  ". Balance: ", DoubleToString(m_account.Balance(),2),
                  ", Equity: ", DoubleToString(m_account.Equity(),2),
                  ", FreeMargin: ", DoubleToString(m_account.FreeMargin(),2));
         if(long_lot==0.0)
           {
            ArrayRemove(SPosition,index,1);
            if(InpPrintLog)
               Print(__FILE__," ",__FUNCTION__,", ERROR: ","CheckOpenLong returned the value of 0.0");
            return;
           }
        }
      else
        {
         if(InpLotOrRisk==lot)
           {
            long_lot=InpVolumeLotOrRisk;
           }
         else
           {
            if(InpLotOrRisk==lots_min)
              {
               long_lot=m_symbol.LotsMin();
              }
            else
              {
               ArrayRemove(SPosition,index,1);
               return;
              }
           }
        }
     }
//---
   if(SPosition[index].lot_coefficient>0.0)
     {
      long_lot=LotCheck(long_lot*SPosition[index].lot_coefficient,
                        m_symbol);
      if(long_lot==0.0)
        {
         ArrayRemove(SPosition,index,1);
         if(InpPrintLog)
            Print(__FILE__," ",__FUNCTION__,", ERROR: ","LotCheck returned the 0.0");
         return;
        }
     }
   if(m_symbol.LotsLimit()>0.0)
     {
      int      count_buys           = 0;
      double   volume_buys          = 0.0;
      double   volume_biggest_buys  = 0.0;
      int      count_sells          = 0;
      double   volume_sells         = 0.0;
      double   volume_biggest_sells = 0.0;
      CalculateAllPositions(count_buys,volume_buys,volume_biggest_buys,
                            count_sells,volume_sells,volume_biggest_sells,
                            true);
      if(volume_buys+volume_sells+long_lot>m_symbol.LotsLimit())
        {
         ArrayRemove(SPosition,index,1);
         if(InpPrintLog)
            Print(__FILE__," ",__FUNCTION__,", ERROR: ","#0 Buy, Volume Buy (",DoubleToString(volume_buys,2),
                  ") + Volume Sell (",DoubleToString(volume_sells,2),
                  ") + Volume long (",DoubleToString(long_lot,2),
                  ") > Lots Limit (",DoubleToString(m_symbol.LotsLimit(),2),")");
         return;
        }
     }
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double free_margin_check=m_account.FreeMarginCheck(m_symbol.Name(),
                            ORDER_TYPE_BUY,
                            long_lot,
                            m_symbol.Ask());
   double margin_check=m_account.MarginCheck(m_symbol.Name(),
                       ORDER_TYPE_BUY,
                       long_lot,
                       m_symbol.Ask());
   if(free_margin_check>margin_check)
     {
      if(m_trade.Buy(long_lot,m_symbol.Name(),m_symbol.Ask(),sl,tp)) // CTrade::Buy -> "true"
        {
         if(m_trade.ResultDeal()==0)
           {
            if(m_trade.ResultRetcode()==10009) // trade order went to the exchange
              {
               SPosition[index].waiting_transaction=true;
               SPosition[index].waiting_order_ticket=m_trade.ResultOrder();
              }
            else
              {
               SPosition[index].waiting_transaction=false;
               if(InpPrintLog)
                  Print(__FILE__," ",__FUNCTION__,", ERROR: ","#1 Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                        ", description of result: ",m_trade.ResultRetcodeDescription());
              }
            if(InpPrintLog)
               PrintResultTrade(m_trade,m_symbol);
           }
         else
           {
            if(m_trade.ResultRetcode()==10009)
              {
               SPosition[index].waiting_transaction=true;
               SPosition[index].waiting_order_ticket=m_trade.ResultOrder();
              }
            else
              {
               SPosition[index].waiting_transaction=false;
               if(InpPrintLog)
                  Print(__FILE__," ",__FUNCTION__,", OK: ","#2 Buy -> true. Result Retcode: ",m_trade.ResultRetcode(),
                        ", description of result: ",m_trade.ResultRetcodeDescription());
              }
            if(InpPrintLog)
               PrintResultTrade(m_trade,m_symbol);
           }
        }
      else
        {
         /*
         10018 TRADE_RETCODE_MARKET_CLOSED   Market is closed
         10026 TRADE_RETCODE_SERVER_DISABLES_AT Autotrading disabled by server
         10027 TRADE_RETCODE_CLIENT_DISABLES_AT Autotrading disabled by client terminal
         10043 TRADE_RETCODE_SHORT_ONLY   The request is rejected, because the "Only short positions are allowed" rule is set for the symbol (POSITION_TYPE_SELL)
         10044 TRADE_RETCODE_CLOSE_ONLY   The request is rejected, because the "Only position closing is allowed" rule is set for the symbol
         */
         uint result_retcode=m_trade.ResultRetcode();
         SPosition[index].waiting_transaction=false;
         if(InpPrintLog)
            Print(__FILE__," ",__FUNCTION__,", ERROR: ","#3 Buy -> false. Result Retcode: ",result_retcode,
                  ", description of result: ",m_trade.ResultRetcodeDescription());
         if(InpPrintLog)
            PrintResultTrade(m_trade,m_symbol);
         if(result_retcode==10018 || result_retcode==10026 || result_retcode==10027 || result_retcode==10043 || result_retcode==10044)
            ArrayRemove(SPosition,index,1);
        }
     }
   else
     {
      ArrayRemove(SPosition,index,1);
      if(InpPrintLog)
         Print(__FILE__," ",__FUNCTION__,", ERROR: ","Free Margin Check (",DoubleToString(free_margin_check,2),") <= Margin Check (",DoubleToString(margin_check,2),")");
      return;
     }
//---
  }
//+------------------------------------------------------------------+
//| Open Sell position                                               |
//+------------------------------------------------------------------+
void OpenSell(const int index)
  {
   double sl=0.0;
   double tp=0.0;
   double short_lot=0.0;
   if(SPosition[index].volume>0.0)
      short_lot=SPosition[index].volume;
   else
     {
      if(InpLotOrRisk==risk)
        {
         short_lot=m_money.CheckOpenShort(m_symbol.Bid(),sl);
         if(InpPrintLog)
            Print(__FILE__," ",__FUNCTION__,", OK: ",
                  "CheckOpenShort (price(",DoubleToString(m_symbol.Bid(),m_symbol.Digits()),"),sl(",DoubleToString(sl,m_symbol.Digits()),"))",
                  " -> Lot: ",DoubleToString(short_lot,2),
                  ". Balance: ", DoubleToString(m_account.Balance(),2),
                  ", Equity: ", DoubleToString(m_account.Equity(),2),
                  ", FreeMargin: ", DoubleToString(m_account.FreeMargin(),2));
         if(short_lot==0.0)
           {
            ArrayRemove(SPosition,index,1);
            if(InpPrintLog)
               Print(__FILE__," ",__FUNCTION__,", ERROR: ","CMoneyFixedMargin.CheckOpenShort returned the value of \"0.0\"");
            return;
           }
        }
      else
        {
         if(InpLotOrRisk==lot)
           {
            short_lot=InpVolumeLotOrRisk;
           }
         else
           {
            if(InpLotOrRisk==lots_min)
              {
               short_lot=m_symbol.LotsMin();
              }
            else
              {
               ArrayRemove(SPosition,index,1);
               return;
              }
           }
        }
     }
//---
   if(SPosition[index].lot_coefficient>0.0)
     {
      short_lot=LotCheck(short_lot*SPosition[index].lot_coefficient,m_symbol);
      if(short_lot==0.0)
        {
         ArrayRemove(SPosition,index,1);
         if(InpPrintLog)
            Print(__FILE__," ",__FUNCTION__,", ERROR: ","LotCheck returned the 0.0");
         return;
        }
     }
   if(m_symbol.LotsLimit()>0.0)
     {
      int      count_buys           = 0;
      double   volume_buys          = 0.0;
      double   volume_biggest_buys  = 0.0;
      int      count_sells          = 0;
      double   volume_sells         = 0.0;
      double   volume_biggest_sells = 0.0;
      CalculateAllPositions(count_buys,volume_buys,volume_biggest_buys,
                            count_sells,volume_sells,volume_biggest_sells,
                            true);
      if(volume_buys+volume_sells+short_lot>m_symbol.LotsLimit())
        {
         ArrayRemove(SPosition,index,1);
         if(InpPrintLog)
            Print(__FILE__," ",__FUNCTION__,", ERROR: ","#0 Buy, Volume Buy (",DoubleToString(volume_buys,2),
                  ") + Volume Sell (",DoubleToString(volume_sells,2),
                  ") + Volume short (",DoubleToString(short_lot,2),
                  ") > Lots Limit (",DoubleToString(m_symbol.LotsLimit(),2),")");
         return;
        }
     }
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double free_margin_check=m_account.FreeMarginCheck(m_symbol.Name(),
                            ORDER_TYPE_SELL,
                            short_lot,
                            m_symbol.Bid());
   double margin_check=m_account.MarginCheck(m_symbol.Name(),
                       ORDER_TYPE_SELL,
                       short_lot,
                       m_symbol.Bid());
   if(free_margin_check>margin_check)
     {
      if(m_trade.Sell(short_lot,m_symbol.Name(),m_symbol.Bid(),sl,tp)) // CTrade::Sell -> "true"
        {
         if(m_trade.ResultDeal()==0)
           {
            if(m_trade.ResultRetcode()==10009) // trade order went to the exchange
              {
               SPosition[index].waiting_transaction=true;
               SPosition[index].waiting_order_ticket=m_trade.ResultOrder();
              }
            else
              {
               SPosition[index].waiting_transaction=false;
               if(InpPrintLog)
                  Print(__FILE__," ",__FUNCTION__,", ERROR: ","#1 Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                        ", description of result: ",m_trade.ResultRetcodeDescription());
              }
            if(InpPrintLog)
               PrintResultTrade(m_trade,m_symbol);
           }
         else
           {
            if(m_trade.ResultRetcode()==10009)
              {
               SPosition[index].waiting_transaction=true;
               SPosition[index].waiting_order_ticket=m_trade.ResultOrder();
              }
            else
              {
               SPosition[index].waiting_transaction=false;
               if(InpPrintLog)
                  Print(__FILE__," ",__FUNCTION__,", OK: ","#2 Sell -> true. Result Retcode: ",m_trade.ResultRetcode(),
                        ", description of result: ",m_trade.ResultRetcodeDescription());
              }
            if(InpPrintLog)
               PrintResultTrade(m_trade,m_symbol);
           }
        }
      else
        {
         /*
         10018 TRADE_RETCODE_MARKET_CLOSED   Market is closed
         10026 TRADE_RETCODE_SERVER_DISABLES_AT Autotrading disabled by server
         10027 TRADE_RETCODE_CLIENT_DISABLES_AT Autotrading disabled by client terminal
         10043 TRADE_RETCODE_SHORT_ONLY   The request is rejected, because the "Only short positions are allowed" rule is set for the symbol (POSITION_TYPE_SELL)
         10044 TRADE_RETCODE_CLOSE_ONLY   The request is rejected, because the "Only position closing is allowed" rule is set for the symbol
         */
         uint result_retcode=m_trade.ResultRetcode();
         SPosition[index].waiting_transaction=false;
         if(InpPrintLog)
            Print(__FILE__," ",__FUNCTION__,", ERROR: ","#3 Sell -> false. Result Retcode: ",result_retcode,
                  ", description of result: ",m_trade.ResultRetcodeDescription());
         if(InpPrintLog)
            PrintResultTrade(m_trade,m_symbol);
         if(result_retcode==10018 || result_retcode==10026 || result_retcode==10027 || result_retcode==10043 || result_retcode==10044)
            ArrayRemove(SPosition,index,1);
        }
     }
   else
     {
      ArrayRemove(SPosition,index,1);
      if(InpPrintLog)
         Print(__FILE__," ",__FUNCTION__,", ERROR: ","Free Margin Check (",DoubleToString(free_margin_check,2),") <= Margin Check (",DoubleToString(margin_check,2),")");
      return;
     }
//---
  }
//+------------------------------------------------------------------+
//| Print CTrade result                                              |
//+------------------------------------------------------------------+
void PrintResultTrade(CTrade &trade,CSymbolInfo &symbol)
  {
   Print(__FILE__," ",__FUNCTION__,", Symbol: ",symbol.Name()+", "+
         "Code of request result: "+IntegerToString(trade.ResultRetcode())+", "+
         "Code of request result as a string: "+trade.ResultRetcodeDescription(),
         "Trade execution mode: "+symbol.TradeExecutionDescription());
   Print("Deal ticket: "+IntegerToString(trade.ResultDeal())+", "+
         "Order ticket: "+IntegerToString(trade.ResultOrder())+", "+
         "Order retcode external: "+IntegerToString(trade.ResultRetcodeExternal())+", "+
         "Volume of deal or order: "+DoubleToString(trade.ResultVolume(),2));
   Print("Price, confirmed by broker: "+DoubleToString(trade.ResultPrice(),symbol.Digits())+", "+
         "Current bid price: "+DoubleToString(symbol.Bid(),symbol.Digits())+" (the requote): "+DoubleToString(trade.ResultBid(),symbol.Digits())+", "+
         "Current ask price: "+DoubleToString(symbol.Ask(),symbol.Digits())+" (the requote): "+DoubleToString(trade.ResultAsk(),symbol.Digits()));
   Print("Broker comment: "+trade.ResultComment());
  }
//+------------------------------------------------------------------+
//| Get value of buffers                                             |
//+------------------------------------------------------------------+
bool iGetArray(const int handle,const int buffer,const int start_pos,
               const int count,double &arr_buffer[])
  {
   bool result=true;
   if(!ArrayIsDynamic(arr_buffer))
     {
      if(InpPrintLog)
         PrintFormat("ERROR! EA: %s, FUNCTION: %s, this a no dynamic array!",__FILE__,__FUNCTION__);
      return(false);
     }
   ArrayFree(arr_buffer);
//--- reset error code
   ResetLastError();
//--- fill a part of the iBands array with values from the indicator buffer
   int copied=CopyBuffer(handle,buffer,start_pos,count,arr_buffer);
   if(copied!=count)
     {
      //--- if the copying fails, tell the error code
      if(InpPrintLog)
         PrintFormat("ERROR! EA: %s, FUNCTION: %s, amount to copy: %d, copied: %d, error code %d",
                     __FILE__,__FUNCTION__,count,copied,GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
     }
   return(result);
  }
//+------------------------------------------------------------------+
//| Close positions                                                  |
//+------------------------------------------------------------------+
void ClosePositions(const ENUM_POSITION_TYPE pos_type)
  {
   for(int i=PositionsTotal()-1; i>=0; i--) // returns the number of current positions
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==InpMagic)
            if(m_position.PositionType()==pos_type)
              {
               if(m_position.PositionType()==POSITION_TYPE_BUY)
                 {
                  if(!m_trade.PositionClose(m_position.Ticket())) // close a position by the specified m_symbol
                     if(InpPrintLog)
                        Print(__FILE__," ",__FUNCTION__,", ERROR: ","BUY PositionClose ",m_position.Ticket(),", ",m_trade.ResultRetcodeDescription());
                 }
               if(m_position.PositionType()==POSITION_TYPE_SELL)
                 {
                  if(!m_trade.PositionClose(m_position.Ticket())) // close a position by the specified m_symbol
                     if(InpPrintLog)
                        Print(__FILE__," ",__FUNCTION__,", ERROR: ","SELL PositionClose ",m_position.Ticket(),", ",m_trade.ResultRetcodeDescription());
                 }
              }
  }
//+------------------------------------------------------------------+
//| Calculate all positions                                          |
//|  'lots_limit=true' - only for 'if(m_symbol.LotsLimit()>0.0)'     |
//+------------------------------------------------------------------+
void CalculateAllPositions(int &count_buys,double &volume_buys,double &volume_biggest_buys,
                           int &count_sells,double &volume_sells,double &volume_biggest_sells,
                           bool lots_limit=false)
  {
   count_buys           = 0;
   volume_buys          = 0.0;
   volume_biggest_buys  = 0.0;
   count_sells          = 0;
   volume_sells         = 0.0;
   volume_biggest_sells = 0.0;
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && (lots_limit || (!lots_limit && m_position.Magic()==InpMagic)))
           {
            if(m_position.PositionType()==POSITION_TYPE_BUY)
              {
               count_buys++;
               volume_buys+=m_position.Volume();
               if(m_position.Volume()>volume_biggest_buys)
                  volume_biggest_buys=m_position.Volume();
               continue;
              }
            else
               if(m_position.PositionType()==POSITION_TYPE_SELL)
                 {
                  count_sells++;
                  volume_sells+=m_position.Volume();
                  if(m_position.Volume()>volume_biggest_sells)
                     volume_biggest_sells=m_position.Volume();
                 }
           }
  }
//+------------------------------------------------------------------+
//| Search trading signals                                           |
//+------------------------------------------------------------------+
bool SearchTradingSignals(void)
  {
   datetime time_0=iTime(m_symbol.Name(),InpWorkingPeriod,0);
   double de_marker[];
   ArraySetAsSeries(de_marker,true);
   int start_pos=0,count=6;
   if(!iGetArray(handle_iDeMarker,0,start_pos,count,de_marker))
      return(false);
   int size_need_position=ArraySize(SPosition);
   if(size_need_position>0)
      return(true);
//--- BUY Signal
   if(de_marker[m_bar_current]<Inp_DeM_LevelDown)
     {
      //---
      ENUM_SYMBOL_TRADE_MODE trade_mode=m_symbol.TradeMode();
      if(trade_mode==SYMBOL_TRADE_MODE_DISABLED)
         return(true);
      //---
      if(!InpReverse)
        {
         if(time_0==m_last_deal_buy_in) // on one bar - only one deal
            return(true);
         //---
         int count_buys=0;
         double profit_buys=0.0;
         int count_sells=0;
         double profit_sells=0.0;
         ProfitAllPositions(count_buys,profit_buys,count_sells,profit_sells);
         if(count_sells>0)
           {
            if(profit_sells>0.0)
               m_need_close_sell=true;
            else
               return(true);
           }
         //---
         ArrayResize(SPosition,size_need_position+1);
         SPosition[size_need_position].pos_type=POSITION_TYPE_BUY;
         if(InpPrintLog)
            Print(__FILE__," ",__FUNCTION__,", OK: ","Signal BUY");
         return(true);
        }
      else
        {
         if(time_0==m_last_deal_sell_in) // on one bar - only one deal
            return(true);
         //---
         int count_buys=0;
         double profit_buys=0.0;
         int count_sells=0;
         double profit_sells=0.0;
         ProfitAllPositions(count_buys,profit_buys,count_sells,profit_sells);
         if(count_buys>0)
           {
            if(profit_buys>0.0)
               m_need_close_buy=true;
            else
               return(true);
           }
         //---
         ArrayResize(SPosition,size_need_position+1);
         SPosition[size_need_position].pos_type=POSITION_TYPE_SELL;
         if(InpPrintLog)
            Print(__FILE__," ",__FUNCTION__,", OK: ","Signal SELL");
         return(true);
        }
     }
//--- SELL Signal
   if(de_marker[m_bar_current]>Inp_DeM_LevelUp)
     {
      if(!InpReverse)
        {
         if(time_0==m_last_deal_sell_in) // on one bar - only one deal
            return(true);
         //---
         int count_buys=0;
         double profit_buys=0.0;
         int count_sells=0;
         double profit_sells=0.0;
         ProfitAllPositions(count_buys,profit_buys,count_sells,profit_sells);
         if(count_buys>0)
           {
            if(profit_buys>0.0)
               m_need_close_buy=true;
            else
               return(true);
           }
         //---
         ArrayResize(SPosition,size_need_position+1);
         SPosition[size_need_position].pos_type=POSITION_TYPE_SELL;
         if(InpPrintLog)
            Print(__FILE__," ",__FUNCTION__,", OK: ","Signal SELL");
         return(true);
        }
      else
        {
         if(time_0==m_last_deal_buy_in) // on one bar - only one deal
            return(true);
         //---
         int count_buys=0;
         double profit_buys=0.0;
         int count_sells=0;
         double profit_sells=0.0;
         ProfitAllPositions(count_buys,profit_buys,count_sells,profit_sells);
         if(count_sells>0)
           {
            if(profit_sells>0.0)
               m_need_close_sell=true;
            else
               return(true);
           }
         //---
         ArrayResize(SPosition,size_need_position+1);
         SPosition[size_need_position].pos_type=POSITION_TYPE_BUY;
         if(InpPrintLog)
            Print(__FILE__," ",__FUNCTION__,", OK: ","Signal BUY");
         return(true);
        }
     }
//---
   return(true);
  }
//+------------------------------------------------------------------+
//| Is position exists                                               |
//+------------------------------------------------------------------+
bool IsPositionExists(void)
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==InpMagic)
            return(true);
//---
   return(false);
  }
//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CloseAllPositions(void)
  {
   if(!RefreshRates())
      return;
   for(int i=PositionsTotal()-1; i>=0; i--) // returns the number of current positions
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==InpMagic)
           {
            if(m_position.PositionType()==POSITION_TYPE_BUY)
              {
               if(!m_trade.PositionClose(m_position.Ticket())) // close a position by the specified m_symbol
                  if(InpPrintLog)
                     Print(__FILE__," ",__FUNCTION__,", ERROR: ","BUY PositionClose ",m_position.Ticket(),", ",m_trade.ResultRetcodeDescription());
              }
            if(m_position.PositionType()==POSITION_TYPE_SELL)
              {
               if(!m_trade.PositionClose(m_position.Ticket())) // close a position by the specified m_symbol
                  if(InpPrintLog)
                     Print(__FILE__," ",__FUNCTION__,", ERROR: ","SELL PositionClose ",m_position.Ticket(),", ",m_trade.ResultRetcodeDescription());
              }
           }
  }
//+------------------------------------------------------------------+
//| Profit all positions                                             |
//+------------------------------------------------------------------+
void ProfitAllPositions(int &count_buys,double &profit_buys,int &count_sells,double &profit_sells)
  {
   count_buys=0;
   profit_buys=0.0;
   count_sells=0;
   profit_sells=0.0;
   for(int i=PositionsTotal()-1; i>=0; i--)
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==InpMagic)
           {
            double profit=m_position.Commission()+m_position.Swap()+m_position.Profit();
            if(m_position.PositionType()==POSITION_TYPE_BUY)
              {
               count_buys++;
               profit_buys+=profit;
              }
            else
              {
               count_sells++;
               profit_sells+=profit;
              }
           }
  }
//+------------------------------------------------------------------+
