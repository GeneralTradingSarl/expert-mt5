//+------------------------------------------------------------------+
//|                                   Exp_ColorXvaMA_Digit_StDev.mq5 |
//|                               Copyright © 2016, Nikolay Kositsin | 
//|                                Khabarovsk, farria@mail.redcom.ru | 
//+------------------------------------------------------------------+
#property copyright "Copyright © 2016, Nikolay Kositsin"
#property link      "farria@mail.redcom.ru"
#property version   "1.00"
//+----------------------------------------------+
//  Торговые алгоритмы                           | 
//+----------------------------------------------+
#include <TradeAlgorithms.mqh>
//+----------------------------------------------+
//|  Перечисление для вариантов расчёта лота     |
//+----------------------------------------------+
/*enum MarginMode  - перечисление объявлено в файле TradeAlgorithms.mqh
  {
   FREEMARGIN=0,     //MM от свободных средств на счёте
   BALANCE,          //MM от баланса средств на счёте
   LOSSFREEMARGIN,   //MM по убыткам от свободных средств на счёте
   LOSSBALANCE,      //MM по убыткам от баланса средств на счёте
   LOT               //Лот без изменения
  }; */
//+----------------------------------------------+
//|  Перечисление для вариантов выхода и входа   |
//+----------------------------------------------+
enum SignalMode
  {
   POINT=0,          //при появлении точечных сигналов (любая точка - сигнал)
   DIRECT,           //при изменении направления движения индикатора
   WITHOUT           //нет разрешения
  };
//+----------------------------------------------+
//|  ОБЪЯВЛЕНИЕ ПЕРЕЧИСЛЕНИЙ                     |
//+----------------------------------------------+
enum Applied_price_ //Тип константы
  {
   PRICE_CLOSE_ = 1,     //Close
   PRICE_OPEN_,          //Open
   PRICE_HIGH_,          //High
   PRICE_LOW_,           //Low
   PRICE_MEDIAN_,        //Median Price (HL/2)
   PRICE_TYPICAL_,       //Typical Price (HLC/3)
   PRICE_WEIGHTED_,      //Weighted Close (HLCC/4)
   PRICE_SIMPL_,         //Simpl Price (OC/2)
   PRICE_QUARTER_,       //Quarted Price (HLOC/4) 
   PRICE_TRENDFOLLOW0_,  //TrendFollow_1 Price 
   PRICE_TRENDFOLLOW1_,  //TrendFollow_2 Price 
   PRICE_DEMARK_         //Demark Price
  };
//+----------------------------------------------+
//|  Описание класса CXMA                        |
//+----------------------------------------------+
#include <SmoothAlgorithms.mqh>
//+----------------------------------------------+
//|  объявление перечислений                     |
//+----------------------------------------------+
/*enum SmoothMethod - перечисление объявлено в файле SmoothAlgorithms.mqh
  {
   MODE_SMA_,  //SMA
   MODE_EMA_,  //EMA
   MODE_SMMA_, //SMMA
   MODE_LWMA_, //LWMA
   MODE_JJMA,  //JJMA
   MODE_JurX,  //JurX
   MODE_ParMA, //ParMA
   MODE_T3,    //T3
   MODE_VIDYA, //VIDYA
   MODE_AMA,   //AMA
  }; */
//+----------------------------------------------+
//| Входные параметры индикатора эксперта        |
//+----------------------------------------------+
input double MM=0.1;                  //Доля финансовых ресурсов от депозита в сделке
input MarginMode MMMode=LOT;          //способ определения размера лота
input int    StopLoss_=1000;          //стоплосс в пунктах
input int    TakeProfit_=2000;        //тейкпрофит в пунктах
input int    Deviation_=10;           //макс. отклонение цены в пунктах
input SignalMode BuyPosOpen=POINT;    //Разрешение для входа в лонг
input SignalMode SellPosOpen=POINT;   //Разрешение для входа в шорт
input SignalMode BuyPosClose=DIRECT;  //Разрешение для выхода из лонгов
input SignalMode SellPosClose=DIRECT; //Разрешение для выхода из шортов
//+----------------------------------------------+
//| Входные параметры индикатора                 |
//+----------------------------------------------+
input ENUM_TIMEFRAMES InpInd_Timeframe=PERIOD_H4; //таймфрейм индикатора
string  SirName="ColorXvaMA_Digit exp";   //Первая часть имени графических объектов
input Smooth_Method XMA_Method1=MODE_EMA_;//метод усреднения
input uint XLength1=15;                   //глубина усреднения                    
input int XPhase1=15;                     //параметр усреднения,
//---- для JJMA изменяющийся в пределах -100 ... +100, влияет на качество переходного процесса;
//---- Для VIDIA это период CMO, для AMA это период медленной скользящей
input Smooth_Method XMA_Method2=MODE_JJMA;//метод сглаживания
input uint XLength2=5;                    //глубина сглаживания                    
input int XPhase2=100;                    //параметр сглаживания,
//---- для JJMA изменяющийся в пределах -100 ... +100, влияет на качество переходного процесса;
input Applied_price_ IPC=PRICE_CLOSE_;    //ценовая константа
//---- Для VIDIA это период CMO, для AMA это период медленной скользящей
input uint Digit=2;                       //количество разрядов округления
input double dK1=1.5;                     //коэффициент 1 для квадратичного фильтра
input double dK2=2.5;                     //коэффициент 2 для квадратичного фильтра
input uint std_period=9;                  //период квадратичного фильтра
input uint SignalBar=1;                           //номер бара для получения сигнала входа
//+----------------------------------------------+
//---- Объявление целых переменных для хранения периода графика в секундах 
int TimeShiftSec;
//---- Объявление целых переменных для хендлов индикаторов
int InpInd_Handle;
//---- объявление целых переменных начала отсчета данных
int min_rates_total;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---- получение хендла индикатора ColorXvaMA_Digit_StDev
   InpInd_Handle=iCustom(Symbol(),InpInd_Timeframe,"ColorXvaMA_Digit_StDev",
                         SirName,XMA_Method1,XLength1,XPhase1,XMA_Method2,XLength2,XPhase2,IPC,0,0,Digit,true,clrGray,dK1,dK2,std_period);
   if(InpInd_Handle==INVALID_HANDLE)
     {
      Print(" Не удалось получить хендл индикатора ColorXvaMA_Digit_StDev");
      return(INIT_FAILED);
     }

//---- инициализация переменной для хранения периода графика в секундах  
   TimeShiftSec=PeriodSeconds(InpInd_Timeframe);

//---- Инициализация переменных начала отсчёта данных
   min_rates_total=GetStartBars(XMA_Method1,XLength1,XPhase1);
   min_rates_total+=GetStartBars(XMA_Method2,XLength2,XPhase2)+int(std_period);
   min_rates_total+=int(3+SignalBar);
//--- завершение инициализации
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//----
   GlobalVariableDel_(Symbol());
//----
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---- проверка количества баров на достаточность для расчёта
   if(BarsCalculated(InpInd_Handle)<min_rates_total) return;

//---- подгрузка истории для нормальной работы функций IsNewBar() и SeriesInfoInteger()  
   LoadHistory(TimeCurrent()-PeriodSeconds(InpInd_Timeframe)-1,Symbol(),InpInd_Timeframe);

//---- Объявление статических переменных
   static bool Recount=true;
   static bool BUY_Open=false,BUY_Close=false;
   static bool SELL_Open=false,SELL_Close=false;
   static datetime UpSignalTime,DnSignalTime;
   static CIsNewBar NB;

//+----------------------------------------------+
//| Определение сигналов для сделок              |
//+----------------------------------------------+
   if(!SignalBar || NB.IsNewBar(Symbol(),InpInd_Timeframe) || Recount) // проверка на появление нового бара
     {
      //---- обнулим торговые сигналы
      BUY_Open=false;
      SELL_Open=false;
      BUY_Close=false;
      SELL_Close=false;
      Recount=false;
      UpSignalTime=datetime(SeriesInfoInteger(Symbol(),InpInd_Timeframe,SERIES_LASTBAR_DATE))+TimeShiftSec;
      DnSignalTime=datetime(SeriesInfoInteger(Symbol(),InpInd_Timeframe,SERIES_LASTBAR_DATE))+TimeShiftSec;

      switch(BuyPosOpen)
        {
         case POINT:
           {
            //---- Объявление локальных переменных
            double Sign1[1],Sign2[1];
            //---- копируем вновь появившиеся данные в массивы
            if(CopyBuffer(InpInd_Handle,3,SignalBar,1,Sign1)<=0) {Recount=true; return;}
            if(CopyBuffer(InpInd_Handle,5,SignalBar,1,Sign2)<=0) {Recount=true; return;}
            if((Sign1[0]!=EMPTY_VALUE) || (Sign2[0]!=EMPTY_VALUE)) BUY_Open=true;
            break;
           }
         case DIRECT:
           {
            //---- Объявление локальных переменных
            double Col[2];
            if(CopyBuffer(InpInd_Handle,1,SignalBar,2,Col)<=0) {Recount=true; return;}
            if(Col[0]<1 && Col[1]==1) BUY_Open=true;
            break;
           }
         case WITHOUT:
           {
            break;
           }
        }

      switch(SellPosOpen)
        {
         case POINT:
           {
            //---- Объявление локальных переменных
            double Sign1[1],Sign2[1];
            //---- копируем вновь появившиеся данные в массивы
            if(CopyBuffer(InpInd_Handle,2,SignalBar,1,Sign1)<=0) {Recount=true; return;}
            if(CopyBuffer(InpInd_Handle,4,SignalBar,1,Sign2)<=0) {Recount=true; return;}
            if((Sign1[0]!=EMPTY_VALUE) || (Sign2[0]!=EMPTY_VALUE)) SELL_Open=true;
            break;
           }
         case DIRECT:
           {
            //---- Объявление локальных переменных
            double Col[2];
            if(CopyBuffer(InpInd_Handle,1,SignalBar,2,Col)<=0) {Recount=true; return;}
            if(Col[0]>0 && Col[1]==0) SELL_Open=true;
            break;
           }
         case WITHOUT:
           {
            break;
           }
        }

      switch(BuyPosClose)
        {
         case POINT:
           {
            //---- Объявление локальных переменных
            double Sign1[1],Sign2[1];
            //---- копируем вновь появившиеся данные в массивы
            if(CopyBuffer(InpInd_Handle,2,SignalBar,1,Sign1)<=0) {Recount=true; return;}
            if(CopyBuffer(InpInd_Handle,4,SignalBar,1,Sign2)<=0) {Recount=true; return;}
            if((Sign1[0]!=EMPTY_VALUE) || (Sign2[0]!=EMPTY_VALUE)) BUY_Close=true;
            break;
           }

         case DIRECT:
           {
            //---- Объявление локальных переменных
            double Col[1];
            if(CopyBuffer(InpInd_Handle,1,SignalBar,1,Col)<=0) {Recount=true; return;}
            if(Col[0]<1) BUY_Close=true;
            break;
           }
         case WITHOUT:
           {
            break;
           }
        }

      switch(SellPosClose)
        {
         case POINT:
           {
            //---- Объявление локальных переменных
            double Sign1[1],Sign2[1];
            //---- копируем вновь появившиеся данные в массивы
            if(CopyBuffer(InpInd_Handle,3,SignalBar,1,Sign1)<=0) {Recount=true; return;}
            if(CopyBuffer(InpInd_Handle,5,SignalBar,1,Sign2)<=0) {Recount=true; return;}
            if((Sign1[0]!=EMPTY_VALUE) || (Sign2[0]!=EMPTY_VALUE)) SELL_Close=true;
            break;
           }
         case DIRECT:
           {
            //---- Объявление локальных переменных
            double Col[1];
            if(CopyBuffer(InpInd_Handle,1,SignalBar,1,Col)<=0) {Recount=true; return;}
            if(Col[0]>0) SELL_Close=true;
            break;
           }
         case WITHOUT:
           {
            break;
           }
        }
     }
//+----------------------------------------------+
//| Совершение сделок                            |
//+----------------------------------------------+
//---- Закрываем лонг
   BuyPositionClose(BUY_Close,Symbol(),Deviation_);

//---- Закрываем шорт   
   SellPositionClose(SELL_Close,Symbol(),Deviation_);

//---- Открываем лонг
   BuyPositionOpen(BUY_Open,Symbol(),UpSignalTime,MM,MMMode,Deviation_,StopLoss_,TakeProfit_);

//---- Открываем шорт
   SellPositionOpen(SELL_Open,Symbol(),DnSignalTime,MM,MMMode,Deviation_,StopLoss_,TakeProfit_);
//----
  }
//+------------------------------------------------------------------+
