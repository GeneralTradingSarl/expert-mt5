//+------------------------------------------------------------------+
//|                                                 ThreeCandles.mq5 |
//|                                            Copyright © 2016, Tor | 
//|                                             http://einvestor.ru/ | 
//+------------------------------------------------------------------+
#property copyright "Copyright © 2016, Tor"
#property link "http://einvestor.ru/"
#property description "Индикатор пытается, анализируя свечные графики, искать точки возможного разворота — паттерны"
//---- номер версии индикатора
#property version   "1.01"
//---- отрисовка индикатора в основном окне
#property indicator_chart_window
//---- для расчета и отрисовки индикатора использовано пять буферов
#property indicator_buffers 5
//---- использовано всего одно графическое построение
#property indicator_plots   1
//+----------------------------------------------+
//|  Параметры отрисовки индикатора              |
//+----------------------------------------------+
//---- в качестве индикатора использованы цветные свечи
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1   clrRed,clrLightPink,clrGray,clrPaleTurquoise,clrMediumSeaGreen
//---- отображение метки индикатора
#property indicator_label1  "ThreeCandles Open;High;Low;Close"
//+----------------------------------------------+
//|  объявление констант                         |
//+----------------------------------------------+
#define RESET  0 // Константа для возврата терминалу команды на пересчёт индикатора
//+----------------------------------------------+
//|  объявление перечислений                     |
//+----------------------------------------------+
enum ENUM_APPLIED_VOLUME_      //Тип константы
  {
   VOLUME_TICK_=0,     //VOLUME_TICK
   VOLUME_REAL_,       //VOLUME_REAL
   VOLUME_NONE         //Без объёмов
  };
//+----------------------------------------------+
//| Входные параметры индикатора                 |
//+----------------------------------------------+
input int maxBar1=300;                               //Max Bar #1 size for disable Volume filter, pips
input ENUM_APPLIED_VOLUME_ VolumeType=VOLUME_TICK_;  //объём 
input uint NumberofBar=1;                            //Номер бара для подачи сигнала
input bool SoundON=true;                             //Разрешение алерта
input uint NumberofAlerts=2;                         //Количество алертов
input bool EMailON=false;                            //Разрешение почтовой отправки сигнала
input bool PushON=false;                             //Разрешение отправки сигнала на мобильный
//+----------------------------------------------+

//---- объявление динамических массивов, которые будут в дальнейшем использованы в качестве индикаторных буферов
double ExtOpenBuffer[];
double ExtHighBuffer[];
double ExtLowBuffer[];
double ExtCloseBuffer[];
double ExtColorBuffer[];

//---- Объявление целых переменных начала отсчёта данных
int min_rates_total;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//----
   min_rates_total=4;
//---- превращение динамических массивов в индикаторные буферы
   SetIndexBuffer(0,ExtOpenBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,ExtHighBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,ExtLowBuffer,INDICATOR_DATA);
   SetIndexBuffer(3,ExtCloseBuffer,INDICATOR_DATA);

//---- превращение динамического массива в цветовой, индексный буфер   
   SetIndexBuffer(4,ExtColorBuffer,INDICATOR_COLOR_INDEX);

//---- индексация элементов в буферах как в таймсериях
   ArraySetAsSeries(ExtOpenBuffer,true);
   ArraySetAsSeries(ExtHighBuffer,true);
   ArraySetAsSeries(ExtLowBuffer,true);
   ArraySetAsSeries(ExtCloseBuffer,true);
   ArraySetAsSeries(ExtColorBuffer,true);

//---- осуществление сдвига начала отсчета отрисовки индикатора 1
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,min_rates_total);
//---- установка значений индикатора, которые не будут видимы на графике
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);

//---- Установка формата точности отображения индикатора
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//---- имя для окон данных и метка для субъокон 
   string short_name="ThreeCandles";
   IndicatorSetString(INDICATOR_SHORTNAME,short_name);
//--- завершение инициализации
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---- проверка количества баров на достаточность для расчёта
   if(rates_total<min_rates_total) return(RESET);

//---- объявления локальных переменных 
   int limit,bar;

//---- расчёты необходимого количества копируемых данных и стартового номера limit для цикла пересчёта баров
   if(prev_calculated>rates_total || prev_calculated<=0)// проверка на первый старт расчёта индикатора
     {
      limit=rates_total-min_rates_total-1; // стартовый номер для расчёта всех баров
     }
   else
     {
      limit=rates_total-prev_calculated; // стартовый номер для расчёта новых баров
     }

//---- индексация элементов в массивах, как в таймсериях  
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(close,true);
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(tick_volume,true);
   ArraySetAsSeries(volume,true);

//---- Основной цикл расчёта индикатора
   for(bar=limit; bar>=0 && !IsStopped(); bar--)
     {
      bool chkVol=true;
      ExtCloseBuffer[bar]=NULL;
      ExtHighBuffer[bar]=NULL;
      ExtLowBuffer[bar]=NULL;
      ExtOpenBuffer[bar]=NULL;
      ExtColorBuffer[bar]=2.0;

      if((high[bar+3]-low[bar+3])/_Point>maxBar1) chkVol=false;

      if(open[bar+3]<close[bar+3] && open[bar+2]<close[bar+2] && close[bar+2]<high[bar+3] && open[bar+1]>close[bar+1] && close[bar+1]<open[bar+2])
        {
         if(chkVol && VolumeType!=VOLUME_NONE)
           {
            if(VolumeType==VOLUME_TICK_)
              {
               if(tick_volume[bar+3]<tick_volume[bar+2] || tick_volume[bar+1]>tick_volume[bar+2] || tick_volume[bar+1]>tick_volume[bar+3])
                 {
                  ExtCloseBuffer[bar]=close[bar];
                  ExtHighBuffer[bar]=high[bar];
                  ExtLowBuffer[bar]=low[bar];
                  ExtOpenBuffer[bar]=open[bar];
                  if(close[bar]<open[bar]) ExtColorBuffer[bar]=0.0;
                  else ExtColorBuffer[bar]=1.0;
                 }
              }

            if(VolumeType==VOLUME_REAL_)
              {
               if(volume[bar+3]<volume[bar+2] || volume[bar+1]>volume[bar+2] || volume[bar+1]>volume[bar+3])
                 {
                  ExtCloseBuffer[bar]=close[bar];
                  ExtHighBuffer[bar]=high[bar];
                  ExtLowBuffer[bar]=low[bar];
                  ExtOpenBuffer[bar]=open[bar];
                  if(close[bar]<open[bar]) ExtColorBuffer[bar]=0.0;
                  else ExtColorBuffer[bar]=1.0;
                 }
              }
           }
         else
           {
            ExtCloseBuffer[bar]=close[bar];
            ExtHighBuffer[bar]=high[bar];
            ExtLowBuffer[bar]=low[bar];
            ExtOpenBuffer[bar]=open[bar];
            if(close[bar]<open[bar]) ExtColorBuffer[bar]=0.0;
            else ExtColorBuffer[bar]=1.0;
           }
        }
         
      if(open[bar+3]>close[bar+3] && open[bar+2]>close[bar+2] && close[bar+2]>low[bar+3] && open[bar+1]<close[bar+1] && close[bar+1]>open[bar+2])
        {
         if(chkVol && VolumeType!=VOLUME_NONE)
           {
            if(VolumeType==VOLUME_TICK_)
              {
               if(tick_volume[bar+3]<tick_volume[bar+2] || tick_volume[bar+1]>tick_volume[bar+2] || tick_volume[bar+1]>tick_volume[bar+3])
                 {
                  ExtCloseBuffer[bar]=close[bar];
                  ExtHighBuffer[bar]=high[bar];
                  ExtLowBuffer[bar]=low[bar];
                  ExtOpenBuffer[bar]=open[bar];
                  if(close[bar]<open[bar]) ExtColorBuffer[bar]=3.0;
                  else ExtColorBuffer[bar]=4.0;
                 }
              }

            if(VolumeType==VOLUME_REAL_)
              {
               if(volume[bar+3]<volume[bar+2] || volume[bar+1]>volume[bar+2] || volume[bar+1]>volume[bar+3])
                 {
                  ExtCloseBuffer[bar]=close[bar];
                  ExtHighBuffer[bar]=high[bar];
                  ExtLowBuffer[bar]=low[bar];
                  ExtOpenBuffer[bar]=open[bar];
                  if(close[bar]<open[bar]) ExtColorBuffer[bar]=3.0;
                  else ExtColorBuffer[bar]=4.0;
                 }
              }
           }
         else
           {
            ExtCloseBuffer[bar]=close[bar];
            ExtHighBuffer[bar]=high[bar];
            ExtLowBuffer[bar]=low[bar];
            ExtOpenBuffer[bar]=open[bar];
            if(close[bar]<open[bar]) ExtColorBuffer[bar]=3.0;
            else ExtColorBuffer[bar]=4.0;
           }
        }
     }
//---     
   BuySignal("ThreeCandles",ExtColorBuffer,rates_total,prev_calculated,close,spread);
   SellSignal("ThreeCandles",ExtColorBuffer,rates_total,prev_calculated,close,spread);
//---    
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Buy signal function                                              |
//+------------------------------------------------------------------+
void BuySignal(string SignalSirname,      // текст имени индикатора для почтовых и пуш-сигналов
               double &Arrow[],           // индикаторный буфер с сигналами для покупки
               const int Rates_total,     // текущее количество баров
               const int Prev_calculated, // количество баров на предыдущем тике
               const double &Close[],     // цена закрытия
               const int &Spread[])       // спред
  {
//---
   static uint counter=0;
   if(Rates_total!=Prev_calculated) counter=0;

   bool BuySignal=false;
   bool SeriesTest=ArrayGetAsSeries(Arrow);
   int index;
   if(SeriesTest) index=int(NumberofBar);
   else index=Rates_total-int(NumberofBar)-1;
   if(Arrow[index]==2) BuySignal=true;
   if(BuySignal && counter<=NumberofAlerts)
     {
      counter++;
      MqlDateTime tm;
      TimeToStruct(TimeCurrent(),tm);
      string text=TimeToString(TimeCurrent(),TIME_DATE)+" "+string(tm.hour)+":"+string(tm.min);
      SeriesTest=ArrayGetAsSeries(Close);
      if(SeriesTest) index=int(NumberofBar);
      else index=Rates_total-int(NumberofBar)-1;
      double Ask=Close[index];
      double Bid=Close[index];
      SeriesTest=ArrayGetAsSeries(Spread);
      if(SeriesTest) index=int(NumberofBar);
      else index=Rates_total-int(NumberofBar)-1;
      Bid+=Spread[index]*_Point;
      string sAsk=DoubleToString(Ask,_Digits);
      string sBid=DoubleToString(Bid,_Digits);
      string sPeriod=GetStringTimeframe(ChartPeriod());
      if(SoundON) Alert("BUY signal \n Ask=",Ask,"\n Bid=",Bid,"\n currtime=",text,"\n Symbol=",Symbol()," Period=",sPeriod);
      if(EMailON) SendMail(SignalSirname+": BUY signal alert","BUY signal at Ask="+sAsk+", Bid="+sBid+", Date="+text+" Symbol="+Symbol()+" Period="+sPeriod);
      if(PushON) SendNotification(SignalSirname+": BUY signal at Ask="+sAsk+", Bid="+sBid+", Date="+text+" Symbol="+Symbol()+" Period="+sPeriod);
     }

//---
  }
//+------------------------------------------------------------------+
//| Sell signal function                                             |
//+------------------------------------------------------------------+
void SellSignal(string SignalSirname,      // текст имени индикатора для почтовых и пуш-сигналов
                double & Arrow[],          // индикаторный буфер с сигналами для покупки
                const int Rates_total,     // текущее количество баров
                const int Prev_calculated, // количество баров на предыдущем тике
                const double &Close[],     // цена закрытия
                const int &Spread[])       // спред
  {
//---
   static uint counter=0;
   if(Rates_total!=Prev_calculated) counter=0;

   bool SellSignal=false;
   bool SeriesTest=ArrayGetAsSeries(Arrow);
   int index;
   if(SeriesTest) index=int(NumberofBar);
   else index=Rates_total-int(NumberofBar)-1;
   if(Arrow[index]==0) SellSignal=true;
   if(SellSignal && counter<=NumberofAlerts)
     {
      counter++;
      MqlDateTime tm;
      TimeToStruct(TimeCurrent(),tm);
      string text=TimeToString(TimeCurrent(),TIME_DATE)+" "+string(tm.hour)+":"+string(tm.min);
      SeriesTest=ArrayGetAsSeries(Close);
      if(SeriesTest) index=int(NumberofBar);
      else index=Rates_total-int(NumberofBar)-1;
      double Ask=Close[index];
      double Bid=Close[index];
      SeriesTest=ArrayGetAsSeries(Spread);
      if(SeriesTest) index=int(NumberofBar);
      else index=Rates_total-int(NumberofBar)-1;
      Bid+=Spread[index]*_Point;
      string sAsk=DoubleToString(Ask,_Digits);
      string sBid=DoubleToString(Bid,_Digits);
      string sPeriod=GetStringTimeframe(ChartPeriod());
      if(SoundON) Alert("SELL signal \n Ask=",Ask,"\n Bid=",Bid,"\n currtime=",text,"\n Symbol=",Symbol()," Period=",sPeriod);
      if(EMailON) SendMail(SignalSirname+": SELL signal alert","SELL signal at Ask="+sAsk+", Bid="+sBid+", Date="+text+" Symbol="+Symbol()+" Period="+sPeriod);
      if(PushON) SendNotification(SignalSirname+": SELL signal at Ask="+sAsk+", Bid="+sBid+", Date="+text+" Symbol="+Symbol()+" Period="+sPeriod);
     }
//---
  }
//+------------------------------------------------------------------+
//|  Получение таймфрейма в виде строки                              |
//+------------------------------------------------------------------+
string GetStringTimeframe(ENUM_TIMEFRAMES timeframe)
  {
//----
   return(StringSubstr(EnumToString(timeframe),7,-1));
//----
  }
//+------------------------------------------------------------------+
