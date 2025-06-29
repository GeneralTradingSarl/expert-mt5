//+------------------------------------------------------------------+ 
//|                                                RVI_Histogram.mq5 | 
//|                               Copyright � 2016, Nikolay Kositsin | 
//|                              Khabarovsk,   farria@mail.redcom.ru | 
//+------------------------------------------------------------------+ 
#property copyright "Copyright � 2011, Nikolay Kositsin"
#property link "farria@mail.redcom.ru"
//---- ����� ������ ����������
#property version   "1.10"
//---- ��������� ���������� � ��������� ����
#property indicator_separate_window 
//---- ���������� ������������ ������� 5
#property indicator_buffers 5 
//---- ������������ ��� ����������� ����������
#property indicator_plots   2
//+-----------------------------------+
//|  ���������� ��������              |
//+-----------------------------------+
#define RESET  0 // ��������� ��� �������� ��������� ������� �� �������� ����������
//+-----------------------------------+
//|  ��������� ��������� ���������� 1 |
//+-----------------------------------+
//---- ��������� ���������� � ���� �������� ������
#property indicator_type1   DRAW_FILLING
//---- � �������� ������ ���������� ������������
#property indicator_color1  clrLime,clrDarkOrange
//---- ����������� ����� ����������
#property indicator_label1  "RVI Signal"
//+-----------------------------------+
//|  ��������� ��������� ���������� 2 |
//+-----------------------------------+
//---- ��������� ���������� � ���� �����������
#property indicator_type2   DRAW_COLOR_HISTOGRAM2
//---- � �������� ������ ���������� ������������
#property indicator_color2  clrCyan,clrGray,clrMagenta
//---- ����� ���������� - ��������
#property indicator_style2 STYLE_SOLID
//---- ������� ����� ���������� ����� 2
#property indicator_width2 2
//---- ����������� ����� ����������
#property indicator_label2  "RVI_Histogram"

//+-----------------------------------+
//|  ������� ��������� ����������     |
//+-----------------------------------+
input uint RVIPeriod=14;                       // ������ ����������
input double HighLevel=+0.3;                   // ������� ����������
input double LowLevel=-0.3;                    // ������� ���������������
input int Shift=0;                             // ����� ���������� �� ����������� � �����
//+-----------------------------------+

//---- ���������� ����� ���������� ������ ������� ������
int  min_rates_total;
//---- ���������� ������������ ��������, ������� ����� � 
// ���������� ������������ � �������� ������������ �������
double UpBuffer[],DnBuffer[],ColorBuffer[],UpBuffer1[],DnBuffer1[];
//---- ���������� ����� ���������� ��� ������� �����������
int RVI_Handle;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//---- ������������� ���������� ������ ������� ������
   min_rates_total=int(RVIPeriod);
//---- ��������� ������ ���������� iRVI
   RVI_Handle=iRVI(NULL,0,RVIPeriod);
   if(RVI_Handle==INVALID_HANDLE)
     {
      Print(" �� ������� �������� ����� ���������� iRVI");
      return(INIT_FAILED);
     }   
   
//---- ����������� ������������� ������� � ������������ �����
   SetIndexBuffer(0,UpBuffer1,INDICATOR_DATA);
//---- ������������� ������ ������ ������� ��������� ����������
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,min_rates_total);
//---- ��������� �������� ����������, ������� �� ����� ������ �� �������
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);
//---- ������������� ������ ���������� �� ����������� �� InpKijun
   PlotIndexSetInteger(0,PLOT_SHIFT,Shift);
//---- ���������� ��������� � ������ ��� � ���������
   ArraySetAsSeries(UpBuffer1,true);

//---- ����������� ������������� ������� � ������������ �����
   SetIndexBuffer(1,DnBuffer1,INDICATOR_DATA);
//---- ���������� ��������� � ������ ��� � ���������
   ArraySetAsSeries(DnBuffer1,true);
     
//---- ����������� ������������� ������� � ������������ �����
   SetIndexBuffer(2,UpBuffer,INDICATOR_DATA);
//---- ������������� ������ ������ ������� ��������� ����������
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,min_rates_total);
//---- ��������� �������� ����������, ������� �� ����� ������ �� �������
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);
//---- ������������� ������ ���������� �� ����������� �� InpKijun
   PlotIndexSetInteger(1,PLOT_SHIFT,Shift);
//---- ���������� ��������� � ������ ��� � ���������
   ArraySetAsSeries(UpBuffer,true);

//---- ����������� ������������� ������� � ������������ �����
   SetIndexBuffer(3,DnBuffer,INDICATOR_DATA);
//---- ���������� ��������� � ������ ��� � ���������
   ArraySetAsSeries(DnBuffer,true);
   
//---- ����������� ������������� ������� � ��������, ��������� �����   
   SetIndexBuffer(4,ColorBuffer,INDICATOR_COLOR_INDEX);
//---- ���������� ��������� � ������ ��� � ���������
   ArraySetAsSeries(ColorBuffer,true);

//--- �������� ����� ��� ����������� � ��������� ������� � �� ����������� ���������
   IndicatorSetString(INDICATOR_SHORTNAME,"RVI_Histogram("+string(RVIPeriod)+")");
//--- ����������� �������� ����������� �������� ����������
   IndicatorSetInteger(INDICATOR_DIGITS,4);
//---- ����������  �������������� ������� ���������� 3   
   IndicatorSetInteger(INDICATOR_LEVELS,3);
//---- �������� �������������� ������� ����������   
   IndicatorSetDouble(INDICATOR_LEVELVALUE,0,HighLevel);
   IndicatorSetDouble(INDICATOR_LEVELVALUE,1,0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE,2,LowLevel);
//---- � �������� ������ ����� �������������� ������� ������������ ����� � ������� �����  
   IndicatorSetInteger(INDICATOR_LEVELCOLOR,0,clrGreen);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR,1,clrGray);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR,2,clrBrown);
//---- � ����� ��������������� ������ ����������� �������� �����-�������  
   IndicatorSetInteger(INDICATOR_LEVELSTYLE,0,STYLE_DASHDOTDOT);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE,1,STYLE_DASHDOTDOT);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE,2,STYLE_DASHDOTDOT);
//---- ���������� �������������
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+  
//| Custom indicator iteration function                              | 
//+------------------------------------------------------------------+  
int OnCalculate(
                const int rates_total,    // ���������� ������� � ����� �� ������� ����
                const int prev_calculated,// ���������� ������� � ����� �� ���������� ����
                const datetime &Time[],
                const double &Open[],
                const double &High[],
                const double &Low[],
                const double &Close[],
                const long &Tick_Volume[],
                const long &Volume[],
                const int &Spread[]
                )
  {
//---- �������� ���������� ����� �� ������������� ��� �������
   if(BarsCalculated(RVI_Handle)<rates_total || rates_total<min_rates_total) return(RESET);

//---- ���������� ��������� ����������
   int to_copy,limit,bar;
   
//---- ������ ���������� ������ limit ��� ����� ��������� �����
   if(prev_calculated>rates_total || prev_calculated<=0)// �������� �� ������ ����� ������� ����������
     {
      limit=rates_total-min_rates_total-1; // ��������� ����� ��� ������� ���� �����
     }
   else limit=rates_total-prev_calculated; // ��������� ����� ��� ������� ����� �����

   to_copy=limit+1;

//---- �������� ����� ����������� ������ � �������
   if(CopyBuffer(RVI_Handle,MAIN_LINE,0,to_copy,UpBuffer)<=0) return(RESET);
   if(CopyBuffer(RVI_Handle,MAIN_LINE,0,to_copy,UpBuffer1)<=0) return(RESET);
   if(CopyBuffer(RVI_Handle,SIGNAL_LINE,0,to_copy,DnBuffer1)<=0) return(RESET);

//---- �������� ���� ��������� ����������
   for(bar=limit; bar>=0 && !IsStopped(); bar--)
     {
      DnBuffer[bar]=0.0;
      int clr=1.0;
      if(UpBuffer[bar]>HighLevel) clr=0.0;
      else if(UpBuffer[bar]<LowLevel) clr=2.0;
      ColorBuffer[bar]=clr;
     }
//----    
   return(rates_total);
  }
//+------------------------------------------------------------------+