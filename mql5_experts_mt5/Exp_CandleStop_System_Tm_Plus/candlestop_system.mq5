//+------------------------------------------------------------------+
//|                                            CandleStop_System.mq5 |
//|                                         Copyright © 2009, CrushD |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2009, CrushD"
#property link "CrushD"
#property description "Индикатор для подтягивания трейлинстопов"
//---- номер версии индикатора
#property version   "1.00"
//---- отрисовка индикатора в главном окне
#property indicator_chart_window 
//---- количество индикаторных буферов 9
#property indicator_buffers 9 
//---- использовано 4 графических построения
#property indicator_plots   4
//+--------------------------------------------+
//| Параметры отрисовки облака                 |
//+--------------------------------------------+
//---- отрисовка индикатора в виде облака
#property indicator_type1   DRAW_FILLING
//---- в качестве цвета линии индикатора использован цвет Lavender
#property indicator_color1 clrLavender
//---- отображение метки индикатора
#property indicator_label1  "CandleStop Channel"
//+--------------------------------------------+
//| Параметры отрисовки уровней                |
//+--------------------------------------------+
//---- отрисовка уровней в виде линий
#property indicator_type2   DRAW_LINE
#property indicator_type3   DRAW_LINE
//---- ввыбор цветов уровней
#property indicator_color2  clrLimeGreen
#property indicator_color3  clrOrange
//---- уровни - штрихпунктирные кривые
#property indicator_style2 STYLE_SOLID
#property indicator_style3 STYLE_SOLID
//---- толщина уровней равна 3
#property indicator_width2  3
#property indicator_width3  3
//---- отображение меток уровней
#property indicator_label2  "CandleStop Up Line"
#property indicator_label3  "CandleStop Down Line"
//+--------------------------------------------+
//| Параметры отрисовки свечей                 |
//+--------------------------------------------+
//---- в качестве индикатора использованы цветные свечи
#property indicator_type4   DRAW_COLOR_CANDLES
#property indicator_color4   clrDeepPink,clrPurple,clrBlue,clrDodgerBlue
//---- отображение метки индикатора
#property indicator_label4  "CandleStop_Open;CandleStop_High;CandleStop_Low;CandleStop_Close"
//+--------------------------------------------+
//| Входные параметры индикатора               |
//+--------------------------------------------+ 
input uint UpTrailPeriods=5; //Период поиска для хая
input uint UpTrailShift=5; //Период сдвига для хая                           
input uint DnTrailPeriods=5; //Период поиска для лоу
input uint DnTrailShift=5; //Период сдвига для хая               
input int Shift=0; // сдвиг индикатора по горизонтали в барах
//+--------------------------------------------+
//---- объявление динамических массивов, которые будут в дальнейшем использованы в качестве индикаторных буферов
double ExtOpenBuffer[],ExtHighBuffer[],ExtLowBuffer[],ExtCloseBuffer[],ExtColorBuffer[];
double UpIndBuffer[],DnIndBuffer[],UpLineBuffer[],DnLineBuffer[];
//---- Объявление целых переменных начала отсчёта данных
int min_rates_total;
//+------------------------------------------------------------------+   
//| CandleStop initialization function                               | 
//+------------------------------------------------------------------+ 
void OnInit()
  {
//---- Инициализация переменных начала отсчёта данных
   min_rates_total=int(MathMax(UpTrailPeriods+UpTrailShift,DnTrailPeriods+DnTrailShift));

//---- превращение динамических массивов в индикаторные буферы
   SetIndexBuffer(0,UpIndBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,DnIndBuffer,INDICATOR_DATA);
//---- осуществление сдвига индикатора 1 по горизонтали
   PlotIndexSetInteger(0,PLOT_SHIFT,Shift);
//---- осуществление сдвига начала отсчета отрисовки индикатора
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,min_rates_total);
//---- установка значений индикатора, которые не будут видимы на графике
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,NULL);
//---- превращение динамических массивов в индикаторные буферы
   SetIndexBuffer(2,UpLineBuffer,INDICATOR_DATA);
   SetIndexBuffer(3,DnLineBuffer,INDICATOR_DATA);
//---- установка позиции, с которой начинается линий канала
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,min_rates_total);
   PlotIndexSetInteger(2,PLOT_DRAW_BEGIN,min_rates_total);
//---- запрет на отрисовку индикатором пустых значений
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,NULL);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,NULL);
//---- осуществление сдвига индикатора по горизонтали
   PlotIndexSetInteger(1,PLOT_SHIFT,Shift);
   PlotIndexSetInteger(2,PLOT_SHIFT,Shift);
//---- превращение динамических массивов в индикаторные буферы
   SetIndexBuffer(4,ExtOpenBuffer,INDICATOR_DATA);
   SetIndexBuffer(5,ExtHighBuffer,INDICATOR_DATA);
   SetIndexBuffer(6,ExtLowBuffer,INDICATOR_DATA);
   SetIndexBuffer(7,ExtCloseBuffer,INDICATOR_DATA);
//---- превращение динамического массива в цветовой, индексный буфер   
   SetIndexBuffer(8,ExtColorBuffer,INDICATOR_COLOR_INDEX);
//---- установка позиции, с которой начинается линий канала
   PlotIndexSetInteger(3,PLOT_DRAW_BEGIN,min_rates_total);
//---- запрет на отрисовку индикатором пустых значений
   PlotIndexSetDouble(3,PLOT_EMPTY_VALUE,NULL);
//---- осуществление сдвига индикатора по горизонтали
   PlotIndexSetInteger(3,PLOT_SHIFT,Shift);
//---- осуществление сдвига индикатора по горизонтали
   //PlotIndexSetInteger(3,PLOT_SHIFT,Shift);
//--- индексация элементов в буфере как в таймсерии
   ArraySetAsSeries(ExtOpenBuffer,true);
   ArraySetAsSeries(ExtHighBuffer,true);
   ArraySetAsSeries(ExtLowBuffer,true);
   ArraySetAsSeries(ExtCloseBuffer,true);
   ArraySetAsSeries(ExtColorBuffer,true);
   ArraySetAsSeries(UpIndBuffer,true);
   ArraySetAsSeries(DnIndBuffer,true);
   ArraySetAsSeries(UpLineBuffer,true);
   ArraySetAsSeries(DnLineBuffer,true);

//--- создание имени для отображения в отдельном подокне и во всплывающей подсказке
   IndicatorSetString(INDICATOR_SHORTNAME,"CandleStop_System");

//--- определение точности отображения значений индикатора
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits+1);
//---- завершение инициализации
  }
//+------------------------------------------------------------------+ 
//| CandleStop iteration function                                    | 
//+------------------------------------------------------------------+ 
int OnCalculate(
                const int rates_total,    // количество истории в барах на текущем тике
                const int prev_calculated,// количество истории в барах на предыдущем тике
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]
                )
  {
//---- проверка количества баров на достаточность для расчёта
   if(rates_total<min_rates_total) return(0);

//---- Объявление переменных с плавающей точкой  
   double HH,LL;
//---- Объявление целых переменных и получение
   int limit;

//---- индексация элементов в массивах, как в таймсериях  
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   
//---- расчет стартового номера limit для цикла пересчета баров
   if(prev_calculated>rates_total || prev_calculated<=0) // проверка на первый старт расчета индикатора
     {
      limit=rates_total-min_rates_total-1;               // стартовый номер для расчета всех баров
     }
   else
     {
      limit=rates_total-prev_calculated;                 // стартовый номер для расчета новых баров
     }

//---- Основной цикл расчёта индикатора
   for(int bar=limit; bar>=0 && !IsStopped(); bar--)
     {
      HH=high[ArrayMaximum(high,bar+UpTrailShift,UpTrailPeriods)];
      LL=low [ArrayMinimum(low, bar+DnTrailShift,DnTrailPeriods)];
      //----
      UpLineBuffer[bar]=UpIndBuffer[bar]=HH;
      DnLineBuffer[bar]=DnIndBuffer[bar]=LL;
      //----
      ExtOpenBuffer[bar]=ExtCloseBuffer[bar]=ExtHighBuffer[bar]=ExtLowBuffer[bar]=NULL;
      ExtColorBuffer[bar]=4;
      //----
      if(close[bar]>HH)
        {
         ExtOpenBuffer[bar]=open[bar];
         ExtCloseBuffer[bar]=close[bar];
         ExtHighBuffer[bar]=high[bar];
         ExtLowBuffer[bar]=low[bar];
         if(close[bar]>=open[bar]) ExtColorBuffer[bar]=3;
         else ExtColorBuffer[bar]=2;
        }
      //----
      if(close[bar]<LL)
        {
         ExtOpenBuffer[bar]=open[bar];
         ExtCloseBuffer[bar]=close[bar];
         ExtHighBuffer[bar]=high[bar];
         ExtLowBuffer[bar]=low[bar];
         if(close[bar]<=open[bar]) ExtColorBuffer[bar]=0;
         else ExtColorBuffer[bar]=1;
        }
     }
//----  
   return(rates_total);
  }
//+------------------------------------------------------------------+
