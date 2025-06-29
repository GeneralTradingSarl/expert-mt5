//+------------------------------------------------------------------+
//|                      SilverTrend v3(barabashkakvn's edition).mq5 |
//+------------------------------------------------------------------+
#property copyright   "fukinagashi"
#property version   "1.001"
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
//--- input parameters
input double   TrailingStop      = 50;
input double   TakeProfit        = 50;
input double   InitialStopLoss   = 0;
input double   FridayNightHour   = 16;
//---
ulong          m_magic=15489;                // magic number
//----
double Lots=0.1;
int Signal,OldSignal;
ENUM_ACCOUNT_MARGIN_MODE m_margin_mode;
double         m_adjusted_point;             // point value adjusted for 3 or 5 points
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetMarginMode();
   if(!IsHedging())
     {
      Print("Hedging only!");
      return(INIT_FAILED);
     }
//---
   m_symbol.Name(Symbol());                  // sets symbol name
   if(!RefreshRates())
     {
      Print("Error RefreshRates. Bid=",DoubleToString(m_symbol.Bid(),Digits()),
            ", Ask=",DoubleToString(m_symbol.Ask(),Digits()));
      return(INIT_FAILED);
     }
   m_symbol.Refresh();
//---
   m_trade.SetExpertMagicNumber(m_magic);    // sets magic number
//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=m_symbol.Point()*digits_adjust;
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
   static datetime bartime=0;
   if(bartime==iTime(m_symbol.Name(),Period(),0))
      return;
   else
      bartime=iTime(m_symbol.Name(),Period(),0);
//---
   double ts=0.0,tp=0.0;
   bool LongSignal=false,ShortSignal=false,ExitLong=false,ExitShort=false;
   string setup="STv3_"+m_symbol.Name()+"_"+EnumToString(Period());

   Signal=SilverTrendSignal();
//---
   double J_TPO=J_TPO(14);
   if(OldSignal!=Signal && Signal>0 && J_TPO>0)
     {
      LongSignal=true;
      ShortSignal=false;
     }
   else if(OldSignal!=Signal && Signal<0 && J_TPO<0)
     {
      LongSignal=false;
      ShortSignal=true;
     }
   else
     {
      LongSignal=false;
      ShortSignal=false;
     }
   Signal=OldSignal;
   if(Signal>0)
     {
      ExitLong=false;
      ExitShort=true;
     }
   else if(Signal<0)
     {
      ExitLong=true;
      ExitShort=false;
        } else {
      ExitLong=false;
      ExitShort=false;
     }
//---
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol()==m_symbol.Name() && m_position.Magic()==m_magic)
           {
            if(m_position.PositionType()==POSITION_TYPE_BUY)
              {
               if(ExitLong)
                 {
                  m_trade.PositionClose(m_position.Ticket()); // close position
                 }
               else if(TrailingStop>0)
                 {
                  if(!RefreshRates())
                     break;
                  if(m_symbol.Bid()-m_position.PriceOpen()>TrailingStop*m_adjusted_point)
                    {
                     ts=m_symbol.Bid()-TrailingStop*m_adjusted_point;
                    }
                  if((m_position.StopLoss()<ts) || (m_position.StopLoss()==0))
                    {
                     m_trade.PositionModify(m_position.Ticket(),
                                            ts,
                                            m_position.TakeProfit());
                    }
                 }
              }
            if(m_position.PositionType()==POSITION_TYPE_SELL)
              {
               if(ExitShort)
                 {
                  m_trade.PositionClose(m_position.Ticket()); // close position
                 }
               else if(TrailingStop>0)
                 {
                  if(!RefreshRates())
                     break;
                  if((m_position.PriceOpen()-m_symbol.Ask())>(TrailingStop*m_adjusted_point))
                    {
                     ts=m_symbol.Ask()+TrailingStop*m_adjusted_point;
                    }
                  if((ts!=0) && ((m_position.StopLoss()>ts) || (m_position.StopLoss()==0)))
                    {
                     m_trade.PositionModify(m_position.Ticket(),
                                            ts,
                                            m_position.TakeProfit());
                    }
                 }
              }
           }
//---
   if(LongSignal)
     {
      MqlDateTime str1;
      TimeToStruct(iTime(m_symbol.Name(),Period(),0),str1);

      if(FridayNightHour>0 && str1.day_of_week==5 && str1.hour>FridayNightHour)
        {
         Print("Friday: No New Trades: "+TimeToString(iTime(m_symbol.Name(),Period(),0),TIME_DATE|TIME_MINUTES));
         return;
        }

      if(!RefreshRates())
         return;

      if(InitialStopLoss>0)
         ts=m_symbol.Ask()-(InitialStopLoss*m_adjusted_point);
      else
         ts=0;

      if(TakeProfit>0)
         tp=m_symbol.Ask()+(TakeProfit*m_adjusted_point);
      else
         tp=0;

      if(m_trade.Buy(Lots,NULL,m_symbol.Ask(),ts,tp,setup))
        {
         if(m_trade.ResultDeal()>0)
            PlaySound("expert.wav");
         else
           {
            PlaySound("alert2.wav");
            Print("Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription(),
                  ", ticket of deal: ",m_trade.ResultDeal());
           }
        }
      else
        {
         PlaySound("alert2.wav");
         Print("Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),
               ", description of result: ",m_trade.ResultRetcodeDescription(),
               ", ticket of deal: ",m_trade.ResultDeal());
        }
     }
   if(ShortSignal)
     {
      MqlDateTime str1;
      TimeToStruct(iTime(m_symbol.Name(),Period(),0),str1);

      if(FridayNightHour>0 && str1.day_of_week==5 && str1.hour>FridayNightHour)
        {
         Print("Friday: No New Trades: "+TimeToString(iTime(m_symbol.Name(),Period(),0),TIME_DATE|TIME_MINUTES));
         return;
        }

      if(!RefreshRates())
         return;

      if(InitialStopLoss>0)
         ts=m_symbol.Bid()+(InitialStopLoss*m_adjusted_point);
      else
         ts=0;

      if(TakeProfit>0)
         tp=m_symbol.Bid()-(TakeProfit*m_adjusted_point);
      else
         tp=0;

      if(m_trade.Sell(Lots,NULL,m_symbol.Bid(),ts,tp,setup))
        {
         if(m_trade.ResultDeal()>0)
            PlaySound("expert.wav");
         else
           {
            PlaySound("alert2.wav");
            Print("Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
                  ", description of result: ",m_trade.ResultRetcodeDescription(),
                  ", ticket of deal: ",m_trade.ResultDeal());
           }
        }
      else
        {
         PlaySound("alert2.wav");
         Print("Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),
               ", description of result: ",m_trade.ResultRetcodeDescription(),
               ", ticket of deal: ",m_trade.ResultDeal());
        }
     }
//---
   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int SilverTrendSignal()
  {
   int RISK=3;
   int CountBars=350;
   int SSP=9;
   int i;
   int i1,i2,K;
   double Range,AvgRange,smin,smax,SsMax,SsMin,price;
   int val=0;
   bool uptrend=false,old=false;
//---
   K=33-RISK;
   for(i=CountBars-SSP; i>=0; i--)
     {
      Range=0;
      AvgRange=0;
      for(i1=i; i1<=i+SSP; i1++)
        {
         AvgRange=AvgRange+MathAbs(iHigh(m_symbol.Name(),Period(),i1)-iLow(m_symbol.Name(),Period(),i1));
        }
      Range=AvgRange/(SSP+1);
      SsMax=iHigh(m_symbol.Name(),Period(),i);
      SsMin=iLow(m_symbol.Name(),Period(),i);
      for(i2=i;i2<=i+SSP-1;i2++)
        {
         price=iHigh(m_symbol.Name(),Period(),i2);
         if(SsMax<price) SsMax=price;
         price=iLow(m_symbol.Name(),Period(),i2);
         if(SsMin>=price) SsMin=price;
        }
      smin=SsMin+(SsMax-SsMin)*K/100;
      smax=SsMax-(SsMax-SsMin)*K/100;
      val=0;
      if(iClose(m_symbol.Name(),Period(),i)<smin)
         uptrend=false;

      if(iClose(m_symbol.Name(),Period(),i)>smax)
         uptrend=true;

      if(uptrend==true)
         val=1;
      else if(uptrend==false)
         val=-1;
      else
         val=0;

      old=uptrend;
     }
   return(val);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double J_TPO(int Len)
  {
   double f8,f10=0.0,f18=0.0,f20=0.0,f30=0.0,f40=0.0,k,
   var14,var18,var1C,var20,var24,value=0.0;
   int f38=0,f48=0,var6,var12,varA,varE;
   double arr0[300],arr1[300],arr2[300],arr3[300];
   ArrayInitialize(arr0,0.0);
   ArrayInitialize(arr1,0.0);
   ArrayInitialize(arr2,0.0);
   ArrayInitialize(arr3,0.0);
//f38=0;
   for(int i=200-Len-100; i>=0; i--)
     {
      var14=0;
      var1C=0;

      if(f38==0)
        {
         f38=1;
         f40=0;
         if(Len-1>=2) f30=Len-1;
         else f30=2;
         f48=(int)f30+1;
         f10=iClose(m_symbol.Name(),Period(),i);
         arr0[f38]=iClose(m_symbol.Name(),Period(),i);
         k=f48;
         f18=12/(k * (k - 1) * (k + 1));
         f20=(f48 + 1) * 0.5;
        }
      else
        {
         if(f38<=f48) f38=f38+1;
         else f38=f48+1;
         f8=f10;
         f10=iClose(m_symbol.Name(),Period(),i);
         if(f38>f48)
           {
            for(var6=2; var6<=f48; var6++) arr0[var6-1]=arr0[var6];
            arr0[f48]=iClose(m_symbol.Name(),Period(),i);
           }
         else arr0[f38]=iClose(m_symbol.Name(),Period(),i);
         if((f30>=f38) && (f8!=f10)) f40=1;
         if((f30==f38) && (f40==0)) f38=0;
        }
      if(f38>=f48)
        {
         for(varA=1; varA<=f48; varA++)
           {
            arr2[varA]=varA;
            arr3[varA]=varA;
            arr1[varA]=arr0[varA];
           }
         for(varA=1; varA<=(f48-1); varA++)
           {
            var24=arr1[varA];
            var12=varA;
            var6=varA+1;
            for(var6=varA+1; var6<=f48; var6++)
              {
               if(arr1[var6]<var24)
                 {
                  var24=arr1[var6];
                  var12=var6;
                 }
              }
            var20=arr1[varA];
            arr1[varA]=arr1[var12];
            arr1[var12]=var20;
            var20=arr2[varA];
            arr2[varA]=arr2[var12];
            arr2[var12]=var20;
           }
         varA=1;
         while(f48>varA)
           {
            var6=varA+1;
            var14=1;
            var1C=arr3[varA];
            while(var14!=0)
              {
               if(arr1[varA]!=arr1[var6])
                 {
                  if((var6-varA)>1)
                    {
                     var1C=var1C/(var6-varA);
                     varE=varA;
                     for(varE=varA; varE<=(var6-1); varE++)
                        arr3[varE]=var1C;
                    }
                  var14=0;
                 }
               else
                 {
                  var1C=var1C+arr3[var6];
                  var6=var6+1;
                 }
              }
            varA=var6;
           }
         var1C=0;
         for(varA=1; varA<=f48; varA++)
            var1C=var1C + (arr3[varA] - f20) * (arr2[varA] - f20);
         var18=f18*var1C;
        }
      else
         var18=0;
      value=var18;
      if(value==0) value=0.00001;
      //ExtMapBuffer1[i]=value;
     }
//--- done
   return(value);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetMarginMode(void)
  {
   m_margin_mode=(ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsHedging(void)
  {
   return(m_margin_mode==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
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
