//+------------------------------------------------------------------+
//|                                                     AutoRisk.mq5 |
//|                                    Copyright 2020, David J. Díez |
//|                         https://www.mql5.com/es/users/davidjdiez |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, David J. Díez Munilla"
#property link      "https://www.mql5.com/en/users/davidjdiez"
#property version   "1.00"
//+--- Definitions --------------------------------------------------!
enum ARMODE{
   Equity=0, // Based on Equity
   Balance=1 // Based on Balance
   };
//+--- Parameters ---------------------------------------------------!
input double RiskFactor = 2.0;  // Risk % on daily ATR
input ARMODE CalcMode   = 1;
input bool   RoundUp    = true; // Round up?
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){return(INIT_SUCCEEDED);}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   double ATR[];ArraySetAsSeries(ATR,true);
   int ATRh=iATR(_Symbol,PERIOD_D1,14);CopyBuffer(ATRh,0,0,100,ATR);
   //+------------------------------------------ Money management ---!
   double Equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double Balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double Tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double LotSize=RiskFactor*(Equity/((ATR[1]/_Point)/Tick)/100);
   if(CalcMode>0){LotSize=RiskFactor*(Balance/((ATR[1]/_Point)/Tick)/100);}
   if(RoundUp==true){LotSize=MathRound(LotSize/minLot)*minLot;} // Round up value.
   else{LotSize=MathFloor(LotSize/minLot)*minLot;}if(LotSize>maxLot){LotSize=maxLot;}
   Comment("\nLotSize: ",DoubleToString(LotSize,2));} // LotSize comment on current chart.
//+------------------------------------------------------------------+