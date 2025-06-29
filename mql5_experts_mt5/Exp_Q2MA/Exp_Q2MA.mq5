//+---------------------------------------------------------------------+
//|                                                        Exp_Q2MA.mq5 |
//|                                  Copyright � 2016, Nikolay Kositsin | 
//|                                 Khabarovsk,   farria@mail.redcom.ru | 
//+---------------------------------------------------------------------+
//| ��� ������  ����������  �������  �������� ���� SmoothAlgorithms.mqh |
//| � ����� (����������): �������_������_���������\\MQL5\Include        |
//+---------------------------------------------------------------------+
#property copyright "Copyright � 2016, Nikolay Kositsin"
#property link      "farria@mail.redcom.ru"
#property version   "1.00"
//+-----------------------------------------------+
//  �������� ���������                            | 
//+-----------------------------------------------+
#include <TradeAlgorithms.mqh>
//+----------------------------------------------+
//|  ������������ ��� ��������� ������� ����     |
//+----------------------------------------------+
/*enum MarginMode  - ������������ ��������� � ����� TradeAlgorithms.mqh
  {
   FREEMARGIN=0,     //MM �� ��������� ������� �� �����
   BALANCE,          //MM �� ������� ������� �� �����
   LOSSFREEMARGIN,   //MM �� ������� �� ��������� ������� �� �����
   LOSSBALANCE,      //MM �� ������� �� ������� ������� �� �����
   LOT               //��� ��� ���������
  }; */
//+----------------------------------------------+
//|  �������� ������ CXMA                        |
//+----------------------------------------------+
#include <SmoothAlgorithms.mqh> 
//+----------------------------------------------+
//|  ���������� ������������                     |
//+----------------------------------------------+
/*enum SmoothMethod - ������������ ��������� � ����� SmoothAlgorithms.mqh
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
//+-----------------------------------------------+
//| ������� ��������� ���������� ��������         |
//+-----------------------------------------------+
input double     MM=0.1;                //���� ���������� �������� � ������
input MarginMode MMMode=LOT;            //������ ����������� ������� ����
input uint       StopLoss_=1000;        //�������� � �������
input uint       TakeProfit_=2000;      //���������� � �������
input uint       Deviation_=10;         //����. ���������� ���� � �������
input bool       BuyPosOpen=true;       //���������� ��� ����� � ����
input bool       SellPosOpen=true;      //���������� ��� ����� � ����
input bool       BuyPosClose=true;      //���������� ��� ������ �� ������ �� �������� �����������
input bool       SellPosClose=true;     //���������� ��� ������ �� ������ �� �������� �����������
input bool       Invert=false;          //�������� ������ ������
//+-----------------------------------------------+
//| ������� ��������� ��� ����������              |
//+-----------------------------------------------+
input ENUM_TIMEFRAMES InpInd_Timeframe=PERIOD_H4;     //��������� ����������
//----
input Smooth_Method XMA_Method=MODE_T3;               //����� ����������
input uint XLength=8;                                 //������� �����������                    
input int XPhase=15;                                  //�������� �����������,
//---- ��� JJMA ������������ � �������� -100 ... +100, ������ �� �������� ����������� ��������;
//---- ��� VIDIA ��� ������ CMO, ��� AMA ��� ������ ��������� ����������
//----
input uint SignalBar=1;                               //����� ���� ��� ��������� ������� �����
//+-----------------------------------------------+
//---- ���������� ����� ���������� ��� �������� ������� ������� � �������� 
int TimeShiftSec;
//---- ���������� ����� ���������� ��� ������� �����������
int InpInd_Handle;
//---- ���������� ����� ���������� ������ ������� ������
int min_rates_total;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---- ��������� ������ ���������� Q2MA
   InpInd_Handle=iCustom(Symbol(),InpInd_Timeframe,"Q2MA",XMA_Method,XLength,XPhase,0,0);
   if(InpInd_Handle==INVALID_HANDLE)
     {
      Print("�� ������� �������� ����� ���������� Q2MA");
      return(INIT_FAILED);
     }

//---- ������������� ���������� ��� �������� ������� ������� � ��������  
   TimeShiftSec=PeriodSeconds(InpInd_Timeframe);

//---- ������������� ���������� ������ ������� ������
   min_rates_total=GetStartBars(XMA_Method,XLength,XPhase);
   min_rates_total+=int(3+SignalBar);
//---- ���������� �������������
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
//---- �������� ���������� ����� �� ������������� ��� �������
   if(BarsCalculated(InpInd_Handle)<min_rates_total) return;

//---- ��������� ������� ��� ���������� ������ ������� IsNewBar() � SeriesInfoInteger()  
   LoadHistory(TimeCurrent()-PeriodSeconds(InpInd_Timeframe)-1,Symbol(),InpInd_Timeframe);

//---- ���������� ����������� ����������
   static bool Recount=true;
   static bool BUY_Open=false,BUY_Close=false;
   static bool SELL_Open=false,SELL_Close=false;
   static datetime UpSignalTime,DnSignalTime;
   static CIsNewBar NB;

//+----------------------------------------------+
//| ����������� �������� ��� ������              |
//+----------------------------------------------+
   if(!SignalBar || NB.IsNewBar(Symbol(),InpInd_Timeframe) || Recount) // �������� �� ��������� ������ ����
     {
      //---- ������� �������� �������
      BUY_Close=false;
      SELL_Close=false;
      Recount=false;

      //---- ���������� ��������� ����������
      double UpIndSeries[2],DnIndSeries[2];

      //---- �������� ����� ����������� ������ � �������
      if(!Invert)
        {
         if(CopyBuffer(InpInd_Handle,0,SignalBar,2,UpIndSeries)<=0) {Recount=true; return;}
         if(CopyBuffer(InpInd_Handle,1,SignalBar,2,DnIndSeries)<=0) {Recount=true; return;}
        }
      else
        {
         if(CopyBuffer(InpInd_Handle,1,SignalBar,2,UpIndSeries)<=0) {Recount=true; return;}
         if(CopyBuffer(InpInd_Handle,0,SignalBar,2,DnIndSeries)<=0) {Recount=true; return;}
        }

      //---- ������� ������� ��� ������� � ����������
      if(UpIndSeries[1]>DnIndSeries[1])
        {
         if(BuyPosOpen && UpIndSeries[0]<=DnIndSeries[0]) BUY_Open=true;
         if(SellPosClose) SELL_Close=true;
         UpSignalTime=datetime(SeriesInfoInteger(Symbol(),InpInd_Timeframe,SERIES_LASTBAR_DATE))+TimeShiftSec;
        }

      //---- ������� ������� ��� ������� � ����������
      if(UpIndSeries[1]<DnIndSeries[1])
        {
         if(SellPosOpen && UpIndSeries[0]>=DnIndSeries[0]) SELL_Open=true;
         if(BuyPosClose) BUY_Close=true;
         DnSignalTime=datetime(SeriesInfoInteger(Symbol(),InpInd_Timeframe,SERIES_LASTBAR_DATE))+TimeShiftSec;
        }
     }
//+----------------------------------------------+
//| ���������� ������                            |
//+----------------------------------------------+
//---- ��������� ����
   BuyPositionClose(BUY_Close,Symbol(),Deviation_);

//---- ��������� ����   
   SellPositionClose(SELL_Close,Symbol(),Deviation_);

//---- ��������� ����
   BuyPositionOpen(BUY_Open,Symbol(),UpSignalTime,MM,MMMode,Deviation_,StopLoss_,TakeProfit_);

//---- ��������� ����
   SellPositionOpen(SELL_Open,Symbol(),DnSignalTime,MM,MMMode,Deviation_,StopLoss_,TakeProfit_);
//----
  }
//+------------------------------------------------------------------+
