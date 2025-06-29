//------------------------------------------------------------------
#property copyright "© mladen, 2018"
#property link      "mladenfx@gmail.com"
#property version   "1.00"
//------------------------------------------------------------------
#property indicator_separate_window
#property indicator_buffers 6
#property indicator_plots   3
#property indicator_label1  "HA oscillator histogram"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrLightSkyBlue,clrSandyBrown
#property indicator_width1  2
#property indicator_label2  "HA oscillator line"
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrLightSkyBlue,clrSandyBrown
#property indicator_label3  "HA oscillator average"
#property indicator_type3   DRAW_COLOR_LINE
#property indicator_color3  clrDodgerBlue,clrCoral
#property indicator_width3  2
//
//---
//
enum enMaTypes
  {
   ma_sma,    // Simple moving average
   ma_ema,    // Exponential moving average
   ma_smma,   // Smoothed MA
   ma_lwma    // Linear weighted MA
  };
input int       inpMaPreSmoothPeriod = 7;           // Pre smoothing average period
input enMaTypes inpMaPreSmoothMethod = ma_lwma;     // Pre smoothing average method
input int       inpMaPosSmoothPeriod = 7;           // Pos smoothing average period
input enMaTypes inpMaPosSmoothMethod = ma_lwma;     // Pos smoothing average method
input int       inpMaPeriod          = 2;           // Signal period
input enMaTypes inpMaMethod          = ma_smma;     // Signal method

double val[],valc[],lin[],linc[],signal[],signalc[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0,val,INDICATOR_DATA);
   SetIndexBuffer(1,valc,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,lin,INDICATOR_DATA);
   SetIndexBuffer(3,linc,INDICATOR_COLOR_INDEX);
   SetIndexBuffer(4,signal,INDICATOR_DATA);
   SetIndexBuffer(5,signalc,INDICATOR_COLOR_INDEX);
   IndicatorSetString(INDICATOR_SHORTNAME,"Heiken ashi smoothed oscillator ("+(string)inpMaPeriod+","+(string)inpMaPreSmoothPeriod+","+(string)inpMaPosSmoothPeriod+")");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator de-initialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
#define _haInstances 1
#define _haSize      5
double workHa[][_haInstances*_haSize];
//
//---
//
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
   if(Bars(_Symbol,_Period)<rates_total) return(-1);
   if(ArrayRange(workHa,0)!=rates_total) ArrayResize(workHa,rates_total);
   int i=(int)MathMax(prev_calculated-1,0); for(; i<rates_total && !_StopFlag; i++)
     {
      double maOpen  = iCustomMa(inpMaPreSmoothMethod,open[i] ,inpMaPreSmoothPeriod,i,rates_total,0);
      double maClose = iCustomMa(inpMaPreSmoothMethod,close[i],inpMaPreSmoothPeriod,i,rates_total,1);
      double maLow   = iCustomMa(inpMaPreSmoothMethod,low[i]  ,inpMaPreSmoothPeriod,i,rates_total,2);
      double maHigh  = iCustomMa(inpMaPreSmoothMethod,high[i] ,inpMaPreSmoothPeriod,i,rates_total,3);     
      double haOpen  = (i>0) ? (workHa[i-1][2]+workHa[i-1][3])/2.0 : (open[i]+close[i])/2;;
      double haClose = (maOpen+maHigh+maLow+maClose)/4.0;
      double haHigh  = MathMax(maHigh, MathMax(haOpen,haClose));
      double haLow   = MathMin(maLow , MathMin(haOpen,haClose));

      if(haOpen  <haClose) { workHa[i][0] = haLow;  workHa[i][1] = haHigh; }
      else                 { workHa[i][0] = haHigh; workHa[i][1] = haLow;  }
                             workHa[i][2] = haOpen;
                             workHa[i][3] = haClose;
                             workHa[i][4] = iCustomMa(inpMaPosSmoothMethod,(haOpen+haClose)/2,inpMaPosSmoothPeriod,i,rates_total,4);

      //
      //---
      //
      val[i] = (i>0) ? workHa[i][4] - workHa[i-1][4] : 0; lin[i] = val[i];
      valc[i]=(val[i]<0) ? 1 : 0; linc[i] = valc[i];
      signal[i] = iCustomMa(inpMaMethod,val[i],inpMaPeriod,i,rates_total,5);
      signalc[i] = (val[i]>signal[i]) ? 0 : (val[i]<signal[i]) ? 1 : (i>0) ? signalc[i-1] : 0;
     }
   return(i);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#define _maWorkBufferx1 6
double iCustomMa(int mode,double price,double length,int r,int bars,int instanceNo=0)
  {
   switch(mode)
     {
      case ma_sma   : return(iSma(price,(int)length,r,bars,instanceNo));
      case ma_ema   : return(iEma(price,length,r,bars,instanceNo));
      case ma_smma  : return(iSmma(price,(int)length,r,bars,instanceNo));
      case ma_lwma  : return(iLwma(price,(int)length,r,bars,instanceNo));
      default       : return(price);
     }
  }
//
//---
//
double workSma[][_maWorkBufferx1];
double iSma(double price,int period,int r,int _bars,int instanceNo=0)
  {
   if(ArrayRange(workSma,0)!=_bars) ArrayResize(workSma,_bars);

   workSma[r][instanceNo]=price;
   double avg=price; int k=1; for(; k<period && (r-k)>=0; k++) avg+=workSma[r-k][instanceNo];
   return(avg/(double)k);
  }
//
//---
//
double workEma[][_maWorkBufferx1];
double iEma(double price,double period,int r,int _bars,int instanceNo=0)
  {
   if(ArrayRange(workEma,0)!=_bars) ArrayResize(workEma,_bars);

   workEma[r][instanceNo]=price;
   if(r>0 && period>1)
      workEma[r][instanceNo]=workEma[r-1][instanceNo]+(2.0/(1.0+period))*(price-workEma[r-1][instanceNo]);
   return(workEma[r][instanceNo]);
  }
//
//---
//
double workSmma[][_maWorkBufferx1];
double iSmma(double price,double period,int r,int _bars,int instanceNo=0)
  {
   if(ArrayRange(workSmma,0)!=_bars) ArrayResize(workSmma,_bars);

   workSmma[r][instanceNo]=price;
   if(r>1 && period>1)
      workSmma[r][instanceNo]=workSmma[r-1][instanceNo]+(price-workSmma[r-1][instanceNo])/period;
   return(workSmma[r][instanceNo]);
  }
//
//---
//
double workLwma[][_maWorkBufferx1];
double iLwma(double price,double period,int r,int _bars,int instanceNo=0)
  {
   if(ArrayRange(workLwma,0)!=_bars) ArrayResize(workLwma,_bars);

   workLwma[r][instanceNo] = price; if(period<1) return(price);
   double sumw = period;
   double sum  = period*price;

   for(int k=1; k<period && (r-k)>=0; k++)
     {
      double weight=period-k;
      sumw  += weight;
      sum   += weight*workLwma[r-k][instanceNo];
     }
   return(sum/sumw);
  }