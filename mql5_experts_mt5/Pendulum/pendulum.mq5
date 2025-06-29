//+------------------------------------------------------------------+
//|                            Pendulum(barabashkakvn's edition).mq5 |
//+------------------------------------------------------------------+
#property version   "1.000"
//---
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
#include <Trade\AccountInfo.mqh>
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
CAccountInfo   m_account;                    // account info wrapper
//--- input parameters
input double   InpLots=1.0;      // Lots
input double   shag              = 0.001;
input double   mnoj              = 2;
input ulong    m_magic=268388736;// magic number
//---
ulong          m_ticket;
ulong          m_slippage=100;   // slippage

double tc=0.0,cos_=0.0,cob_=0.0,sl_=0.0,tp_=0.0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   if(!m_symbol.Name(Symbol())) // sets symbol name
      return(INIT_FAILED);
   RefreshRates();
//---
   m_trade.SetExpertMagicNumber(m_magic);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(m_symbol.Name());
   m_trade.SetDeviationInPoints(m_slippage);
//--- check the input parameter "Lots"
   string err_text="";
   if(!CheckVolumeValue(InpLots,err_text))
     {
      //--- when testing, we will only output to the log about incorrect input parameters
      if(MQLInfoInteger(MQL_TESTER))
        {
         Print(__FUNCTION__,", ERROR: ",err_text);
         return(INIT_FAILED);
        }
      else // if the Expert Advisor is run on the chart, tell the user about the error
        {
         Alert(__FUNCTION__,", ERROR: ",err_text);
         return(INIT_PARAMETERS_INCORRECT);
        }
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
//---
   if(!RefreshRates())
      return;
   double bid=m_symbol.Bid();
   tc=NormalizeDouble(MathCeil(bid/shag)*shag,m_symbol.Digits());

   if(cos_==0)
      cos_=tc-shag;
   if(cob_==0)
      cob_=tc;

   ulong tickets[4];
   ArrayInitialize(tickets,0);
   long positions[4];
   ArrayInitialize(positions,-1);

   int total=0;
//--- обратный обход только для подсчёта. для закрытия позиций такой обход нельзя!!!
   for(int i=0;i<PositionsTotal();i++)
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
           {
            total++;
            if(total>3)
               return;
            tickets[total]=m_position.Ticket();
            positions[total]=m_position.PositionType();
           }

   if(total==0)
     {
      if(cob_<=bid)
        {
         OpenBuy(InpLots,0.0,0.0);
         sl_ = cob_ - shag*2;
         tp_ = cob_ + shag;
         cos_ = cob_ - shag;
         cob_ = cob_ + shag;
        }
      if(cos_>=bid)
        {
         OpenSell(InpLots,0.0,0.0);
         sl_ = cos_ + shag*2;
         tp_ = cos_ - shag;
         cob_ = cos_ + shag;
         cos_ = cos_ - shag;
        }
     }
//---
   if(total==1)
     {
      if(positions[1]==POSITION_TYPE_BUY)
        {
         if(cos_>=bid)
           {
            OpenSell(InpLots*2.0,0.0,0.0);
            sl_   = cos_ + shag;
            tp_   = cos_ - shag*mnoj;
            cob_  = cos_ + shag;
            cos_  = cos_ - shag * mnoj;
            return;
           }
         if(tp_<=bid)
           {
            if(m_trade.PositionClose(tickets[1]))
              {
               OpenBuy(InpLots,0.0,0.0);
               cob_= tp_;
               sl_ = cob_ - shag*2;
               tp_ = cob_ + shag;
               cos_= cob_-shag;
               return;
              }
           }
        }
      if(positions[1]==POSITION_TYPE_SELL)
        {
         if(cob_<=bid)
           {
            OpenBuy(InpLots*2.0,0.0,0.0);
            sl_ = cob_ - shag;
            tp_ = cob_ + shag*mnoj;
            cos_ = cob_ - shag;
            cob_ = cob_ + shag*mnoj;
            return;
           }
         if(tp_>=bid)
           {
            if(m_trade.PositionClose(tickets[1]))
              {
               OpenSell(InpLots,0.0,0.0);
               cos_= tp_;
               sl_ = cos_ + shag*2;
               tp_ = cos_ - shag;
               cob_= cos_+shag;
              }
           }
        }
     }
//---
   if(total==2)
     {
      if(positions[2]==POSITION_TYPE_BUY)
        {
         if(cos_>=bid)
           {
            OpenSell(InpLots*4.0,0.0,0.0);
            sl_ = cos_ + shag;
            tp_ = cos_ - shag*mnoj;
            cob_ = cos_ + shag;
            cos_ = cos_ - shag*mnoj;
            return;
           }
         if(tp_<=bid)
           {
            m_trade.PositionClose(tickets[1]);
            m_trade.PositionClosePartial(tickets[1],InpLots*2.0);
            cob_ = tp_;
            cos_ = tp_ - shag;
            return;
           }
        }
      if(positions[2]==POSITION_TYPE_SELL)
        {
         if(cob_<=bid)
           {
            OpenBuy(InpLots*4.0,0.0,0.0);
            sl_ = cob_ - shag;
            tp_ = cob_ + shag*mnoj;
            cos_ = cob_ - shag;
            cob_ = cob_ + shag*mnoj;
            return;
           }
         if(tp_>=bid)
           {
            m_trade.PositionClose(tickets[1]);
            m_trade.PositionClosePartial(tickets[1],InpLots*2.0);
            cos_ = tp_;
            cob_ = tp_ + shag;
            return;
           }
        }
     }
//---
   if(total==3)
     {
      if(positions[3]==POSITION_TYPE_BUY)
        {
         if(tp_<=bid)
           {
            m_trade.PositionClose(tickets[1]);
            m_trade.PositionClosePartial(tickets[2],InpLots*2.0);
            m_trade.PositionClosePartial(tickets[3],InpLots*4.0);
            cob_ = tp_;
            cos_ = tp_ - shag;
            return;
           }
         if(sl_>=bid)
           {
            m_trade.PositionClose(tickets[1]);
            m_trade.PositionClosePartial(tickets[2],InpLots*2.0);
            m_trade.PositionClosePartial(tickets[3],InpLots*4.0);
            cos_ = sl_ - shag;
            cob_ = sl_ + shag;
            return;
           }
        }
      if(positions[3]==POSITION_TYPE_SELL)
        {
         if(tp_>=bid)
           {
            m_trade.PositionClose(tickets[1]);
            m_trade.PositionClosePartial(tickets[2],InpLots*2.0);
            m_trade.PositionClosePartial(tickets[3],InpLots*4.0);
            cos_ = tp_;
            cob_ = tp_ + shag;
            return;
           }
         if(sl_<=bid)
           {
            m_trade.PositionClose(tickets[1]);
            m_trade.PositionClosePartial(tickets[2],InpLots*2.0);
            m_trade.PositionClosePartial(tickets[3],InpLots*4.0);
            cob_ = sl_ + shag;
            cos_ = sl_ - shag;
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
//--- get transaction type as enumeration value 
   ENUM_TRADE_TRANSACTION_TYPE type=trans.type;
//--- if transaction is result of addition of the transaction in history
   if(type==TRADE_TRANSACTION_DEAL_ADD)
     {
      long     deal_ticket       =0;
      long     deal_order        =0;
      long     deal_time         =0;
      long     deal_time_msc     =0;
      long     deal_type         =-1;
      long     deal_entry        =-1;
      long     deal_magic        =0;
      long     deal_reason       =-1;
      long     deal_position_id  =0;
      double   deal_volume       =0.0;
      double   deal_price        =0.0;
      double   deal_commission   =0.0;
      double   deal_swap         =0.0;
      double   deal_profit       =0.0;
      string   deal_symbol       ="";
      string   deal_comment      ="";
      string   deal_external_id  ="";
      if(HistoryDealSelect(trans.deal))
        {
         deal_ticket       =HistoryDealGetInteger(trans.deal,DEAL_TICKET);
         deal_order        =HistoryDealGetInteger(trans.deal,DEAL_ORDER);
         deal_time         =HistoryDealGetInteger(trans.deal,DEAL_TIME);
         deal_time_msc     =HistoryDealGetInteger(trans.deal,DEAL_TIME_MSC);
         deal_type         =HistoryDealGetInteger(trans.deal,DEAL_TYPE);
         deal_entry        =HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
         deal_magic        =HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
         deal_reason       =HistoryDealGetInteger(trans.deal,DEAL_REASON);
         deal_position_id  =HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);

         deal_volume       =HistoryDealGetDouble(trans.deal,DEAL_VOLUME);
         deal_price        =HistoryDealGetDouble(trans.deal,DEAL_PRICE);
         deal_commission   =HistoryDealGetDouble(trans.deal,DEAL_COMMISSION);
         deal_swap         =HistoryDealGetDouble(trans.deal,DEAL_SWAP);
         deal_profit       =HistoryDealGetDouble(trans.deal,DEAL_PROFIT);

         deal_symbol       =HistoryDealGetString(trans.deal,DEAL_SYMBOL);
         deal_comment      =HistoryDealGetString(trans.deal,DEAL_COMMENT);
         deal_external_id  =HistoryDealGetString(trans.deal,DEAL_EXTERNAL_ID);
        }
      else
         return;
      if(deal_symbol==m_symbol.Name() && deal_magic==m_magic)
         if(deal_entry==DEAL_ENTRY_IN)
            if(deal_type==DEAL_TYPE_BUY || deal_type==DEAL_TYPE_SELL)
              {

              }
     }
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
//| Open Buy position                                                |
//+------------------------------------------------------------------+
bool OpenBuy(const double lot,double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);

   double long_lot=lot;
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double free_margin_check= m_account.FreeMarginCheck(m_symbol.Name(),ORDER_TYPE_BUY,long_lot,m_symbol.Ask());
   double margin_check     = m_account.MarginCheck(m_symbol.Name(),ORDER_TYPE_SELL,long_lot,m_symbol.Bid());
   if(free_margin_check>margin_check)
     {
      if(m_trade.Buy(long_lot,m_symbol.Name(),m_symbol.Ask(),sl,tp))
        {
         if(m_trade.ResultDeal()==0)
           {
            Print("#1 Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResultTrade(m_trade,m_symbol);
            return(false);
           }
         else
           {
            Print("#2 Buy -> true. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResultTrade(m_trade,m_symbol);
            return(true);
           }
        }
      else
        {
         Print("#3 Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
               ", description of result: ",m_trade.ResultRetcodeDescription());
         PrintResultTrade(m_trade,m_symbol);
         return(false);
        }
     }
   else
     {
      Print(__FUNCTION__,", ERROR: method CAccountInfo::FreeMarginCheck returned the value ",DoubleToString(free_margin_check,2));
      return(false);
     }
//---
  }
//+------------------------------------------------------------------+
//| Open Sell position                                               |
//+------------------------------------------------------------------+
bool OpenSell(const double lot,double sl,double tp)
  {
   sl=m_symbol.NormalizePrice(sl);
   tp=m_symbol.NormalizePrice(tp);

   double short_lot=lot;
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double free_margin_check= m_account.FreeMarginCheck(m_symbol.Name(),ORDER_TYPE_SELL,short_lot,m_symbol.Bid());
   double margin_check     = m_account.MarginCheck(m_symbol.Name(),ORDER_TYPE_SELL,short_lot,m_symbol.Bid());
   if(free_margin_check>margin_check)
     {
      if(m_trade.Sell(short_lot,m_symbol.Name(),m_symbol.Bid(),sl,tp))
        {
         if(m_trade.ResultDeal()==0)
           {
            Print("#1 Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResultTrade(m_trade,m_symbol);
            return(false);
           }
         else
           {
            Print("#2 Sell -> true. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResultTrade(m_trade,m_symbol);
            return(true);
           }
        }
      else
        {
         Print("#3 Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
               ", description of result: ",m_trade.ResultRetcodeDescription());
         PrintResultTrade(m_trade,m_symbol);
         return(false);
        }
     }
   else
     {
      Print(__FUNCTION__,", ERROR: method CAccountInfo::FreeMarginCheck returned the value ",DoubleToString(free_margin_check,2));
      return(false);
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
