//+------------------------------------------------------------------+
//|                                                  Exp_BlauHLM.mq5 |
//|                               Copyright � 2014, Nikolay Kositsin | 
//|                              Khabarovsk,   farria@mail.redcom.ru | 
//+------------------------------------------------------------------+
#property copyright "Copyright � 2014, Nikolay Kositsin"
#property link      "farria@mail.redcom.ru"
#property version   "1.00"
//+----------------------------------------------+
//| �������� ������ CXMA                         |
//+----------------------------------------------+
#include <SmoothAlgorithms.mqh> 
//+----------------------------------------------+
//| ���������� ������������                      |
//+----------------------------------------------+
enum AlgMode
  {
   breakdown,  // ������ ���� ������������
   twist,      // ��������� ����������� �����������
   cloudtwist  // ��������� ����� ����������� ������
  };
//+----------------------------------------------+
//| ���������� ������������                      |
//+----------------------------------------------+
/*
enum Smooth_Method
  {
   MODE_SMA_,  // SMA
   MODE_EMA_,  // EMA
   MODE_SMMA_, // SMMA
   MODE_LWMA_, // LWMA
   MODE_JJMA,  // JJMA
   MODE_JurX,  // JurX
   MODE_ParMA, // ParMA
   MODE_T3,    // T3
   MODE_VIDYA, // VIDYA
   MODE_AMA,   // AMA
  };
*/
//+----------------------------------------------+
//| �������� ���������                           |
//+----------------------------------------------+
#include <TradeAlgorithms.mqh>
//+----------------------------------------------+
//| ������� ��������� ��������                   |
//+----------------------------------------------+
input double MM=0.1;               // ���� ���������� �������� �� �������� � ������, ������������� �������� - ������ ����
input MarginMode MMMode=LOT;       // ������ ����������� ������� ����
input int     StopLoss_=1000;      // Stop Loss � �������
input int     TakeProfit_=2000;    // Take Profit � �������
input int     Deviation_=10;       // ����. ���������� ���� � �������
input bool    BuyPosOpen=true;     // ���������� ��� ����� � ����
input bool    SellPosOpen=true;    // ���������� ��� ����� � ����
input bool    BuyPosClose=true;    // ���������� ��� ������ �� ������
input bool    SellPosClose=true;   // ���������� ��� ������ �� ������
input AlgMode Mode=twist;          // �������� ��� ����� � �����
//+----------------------------------------------+
//| ������� ��������� ����������                 |
//+----------------------------------------------+
input ENUM_TIMEFRAMES InpInd_Timeframe=PERIOD_H4; // ��������� ����������
input Smooth_Method XMA_Method=MODE_EMA;          // ����� ����������
input uint XLength=2;                             // ������ ���������
input uint XLength1=20;                           // ������� ������� ����������
input uint XLength2=5;                            // ������� ������� ����������
input uint XLength3=3;                            // ������� �������� ����������
input uint XLength4=3;                            // ������� ���������� ���������� �����
input int XPhase=15;                              // �������� �����������
//---- ��� JJMA ������������ � �������� -100 ... +100, ������ �� �������� ����������� ��������;
//---- ��� VIDIA ��� ������ CMO, ��� AMA ��� ������ ��������� ����������
input uint SignalBar=1;                           // ����� ���� ��� ��������� ������� �����
//+----------------------------------------------+
//--- ���������� ������������� ���������� ��� �������� ������� ������� � �������� 
int TimeShiftSec;
//--- ���������� ������������� ���������� ��� ������� �����������
int InpInd_Handle;
//--- ���������� ������������� ���������� ������ ������� ������
int min_rates_total;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- ��������� ������ ���������� BlauHLM
   InpInd_Handle=iCustom(Symbol(),InpInd_Timeframe,"BlauHLM",XMA_Method,XLength,XLength1,XLength2,XLength3,XLength4,XPhase);
   if(InpInd_Handle==INVALID_HANDLE)
     {
      Print(" �� ������� �������� ����� ���������� BlauHLM");
      return(INIT_FAILED);
     }
//--- ������������� ���������� ��� �������� ������� ������� � ��������  
   TimeShiftSec=PeriodSeconds(InpInd_Timeframe);
//--- ������������� ���������� ������ ������� ������
   min_rates_total=int(XLength);
   min_rates_total+=GetStartBars(XMA_Method,XLength1,XPhase);
   min_rates_total+=GetStartBars(XMA_Method,XLength2,XPhase);
   min_rates_total+=GetStartBars(XMA_Method,XLength3,XPhase);
   min_rates_total+=GetStartBars(XMA_Method,XLength4,XPhase);
   min_rates_total=int(min_rates_total+3+SignalBar);
//--- ���������� �������������
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   GlobalVariableDel_(Symbol());
//---
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- �������� ���������� ����� �� ������������� ��� �������
   if(BarsCalculated(InpInd_Handle)<min_rates_total) return;
//--- ��������� ������� ��� ���������� ������ ������� IsNewBar() � SeriesInfoInteger()  
   LoadHistory(TimeCurrent()-PeriodSeconds(InpInd_Timeframe)-1,Symbol(),InpInd_Timeframe);
//--- ���������� ����������� ����������
   static bool Recount=true;
   static bool BUY_Open=false,BUY_Close=false;
   static bool SELL_Open=false,SELL_Close=false;
   static datetime UpSignalTime,DnSignalTime;
   static CIsNewBar NB;
//--- ����������� �������� ��� ������
   if(!SignalBar || NB.IsNewBar(Symbol(),InpInd_Timeframe) || Recount) // �������� �� ��������� ������ ����
     {
      //--- ������� �������� �������
      BUY_Open=false;
      SELL_Open=false;
      BUY_Close=false;
      SELL_Close=false;
      Recount=false;
      //---
      switch(Mode)
        {
         case breakdown: //������ ���� ������������
           {
            double Hist[2];
            //--- �������� ����� ����������� ������ � �������
            if(CopyBuffer(InpInd_Handle,2,SignalBar,2,Hist)<=0) {Recount=true; return;}
            //--- ������� ������� ��� �������
            if(Hist[1]>0)
              {
               if(BuyPosOpen  &&  Hist[0]<=0) BUY_Open=true;
               if(SellPosClose) SELL_Close=true;
               UpSignalTime=datetime(SeriesInfoInteger(Symbol(),InpInd_Timeframe,SERIES_LASTBAR_DATE))+TimeShiftSec;
              }
            //--- ������� ������� ��� �������
            if(Hist[1]<0)
              {
               if(SellPosOpen && Hist[0]>=0) SELL_Open=true;
               if(BuyPosClose) BUY_Close=true;
               DnSignalTime=datetime(SeriesInfoInteger(Symbol(),InpInd_Timeframe,SERIES_LASTBAR_DATE))+TimeShiftSec;
              }
           }
         break;

         case twist://��������� �����������
           {
            double Hist[3];
            //--- �������� ����� ����������� ������ � �������
            if(CopyBuffer(InpInd_Handle,2,SignalBar,3,Hist)<=0) {Recount=true; return;}
            //--- ������� ������� ��� �������
            if(Hist[1]<Hist[2])
              {
               if(BuyPosOpen && Hist[0]>Hist[1]) BUY_Open=true;
               if(SellPosClose) SELL_Close=true;
               UpSignalTime=datetime(SeriesInfoInteger(Symbol(),InpInd_Timeframe,SERIES_LASTBAR_DATE))+TimeShiftSec;
              }
            //--- ������� ������� ��� �������
            if(Hist[1]>Hist[2])
              {
               if(SellPosOpen && Hist[0]<Hist[1]) SELL_Open=true;
               if(BuyPosClose) BUY_Close=true;
               DnSignalTime=datetime(SeriesInfoInteger(Symbol(),InpInd_Timeframe,SERIES_LASTBAR_DATE))+TimeShiftSec;
              }
           }
         break;

         case cloudtwist: //��������� ����� ����������� ������
           {
            double Up[2],Dn[2];
            //--- �������� ����� ����������� ������ � �������
            if(CopyBuffer(InpInd_Handle,0,SignalBar,2,Up)<=0) {Recount=true; return;}
            if(CopyBuffer(InpInd_Handle,1,SignalBar,2,Dn)<=0) {Recount=true; return;}
            //--- ������� ������� ��� �������
            if(Up[1]>Dn[1])
              {
               if(BuyPosOpen   &&   Up[0]<=Dn[0]) BUY_Open=true;
               if(SellPosClose) SELL_Close=true;
               UpSignalTime=datetime(SeriesInfoInteger(Symbol(),InpInd_Timeframe,SERIES_LASTBAR_DATE))+TimeShiftSec;
              }
            //--- ������� ������� ��� �������
            if(Up[1]<Dn[1])
              {
               if(SellPosOpen && Up[0]>=Dn[0]) SELL_Open=true;
               if(BuyPosClose) BUY_Close=true;
               DnSignalTime=datetime(SeriesInfoInteger(Symbol(),InpInd_Timeframe,SERIES_LASTBAR_DATE))+TimeShiftSec;
              }
           }
         break;
        }
     }
//--- ���������� ������
//--- ��������� ����
   BuyPositionClose(BUY_Close,Symbol(),Deviation_);
//--- ��������� ����   
   SellPositionClose(SELL_Close,Symbol(),Deviation_);
//--- ��������� ����
   BuyPositionOpen(BUY_Open,Symbol(),UpSignalTime,MM,MMMode,Deviation_,StopLoss_,TakeProfit_);
//--- ��������� ����
   SellPositionOpen(SELL_Open,Symbol(),DnSignalTime,MM,MMMode,Deviation_,StopLoss_,TakeProfit_);
//---
  }
//+------------------------------------------------------------------+
