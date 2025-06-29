//+------------------------------------------------------------------+
//|                                                  Well Martin.mq5 |
//|                                              Copyright 2015, AM2 |
//|                                      http://www.forexsystems.biz |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, AM2"
#property link      "http://www.forexsystems.biz"
#property version   "1.00"
//---
#include <Trade\Trade.mqh>            // ���������� �������� ����� CTrade
//--- ������� ��������� ���������� Bollinger Bands
input int      BBPeriod  = 84;        // ������ Bollinger Bands
input int      BBShift   = 0;         // �������� ������������ �������
input double   BBDev     = 1.8;       // ����������� ����������
//--- ������� ��������� ���������� ADX
input int      ADXPeriod = 40;        // ������ ADX
input int      ADXLevel  = 45;        // ������� ADX
//--- ������� ��������� ��������
input int      TP        = 1200;      // ����-������
input int      SL        = 1400;      // ����-����
input int      Slip      = 50;        // ���������������
input int      Stelth    = 0;         // 1-����� ����� ����� ������ ������������
input double   KLot      = 2;         // ����������� ��������� ����
input double   MaxLot    = 5;         // ������������ ���, ����� �������� ��� ���������
input double   Lot       = 0.1;       // ���������� ����� ��� �������� 
input color    LableClr  = clrGreen;  // ���� �����
//--- ���������� ����������
int BBHandle;                         // ����� ���������� Bolinger Bands
int ADXHandle;                        // ����� ���������� ADX
double BBUp[],BBLow[];                // ������������ ������� ��� �������� ��������� �������� Bollinger Bands
double ADX[];                         // ������������ ������� ��� �������� ��������� �������� ADX
CTrade trade;                         // ���������� �������� ����� CTrade
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- �������� ����� �����������  Bollinger Bands � ADX
   BBHandle=iBands(_Symbol,0,BBPeriod,BBShift,BBDev,PRICE_CLOSE);
   ADXHandle=iADX(_Symbol,0,ADXPeriod);

//--- ����� ���������, �� ���� �� ���������� �������� Invalid Handle
   if(BBHandle==INVALID_HANDLE || ADXHandle==INVALID_HANDLE)
     {
      Print(" �� ������� �������� ����� �����������");
      return(INIT_FAILED);
     }
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- ����������� ������ �����������
   IndicatorRelease(BBHandle);
   IndicatorRelease(ADXHandle);
//--- ������ ��������� �����
   ObjectsDeleteAll(0,0,OBJ_ARROW_LEFT_PRICE);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- ����� ��������� ����, ������ � ����� ��� ������� ����
   MqlRates mrate[];
//--- ��������� ���������� � �������� ��������� � �����������  ��� � ����������
//--- ������ ���������
   ArraySetAsSeries(mrate,true);
//--- ������ �������� �����������
   ArraySetAsSeries(BBUp,true);
   ArraySetAsSeries(BBLow,true);
   ArraySetAsSeries(ADX,true);
//--- ������� ������������ ������ ��������� 3-� �����
   if(CopyRates(_Symbol,_Period,0,3,mrate)<0)
     {
      Alert("������ ����������� ������������ ������ - ������:",GetLastError(),"!!");
      return;
     }
//--- �������� �������� ���������� Bolinger Bands ��������� ������
   if(CopyBuffer(BBHandle,1,0,3,BBUp)<0 || CopyBuffer(BBHandle,2,0,3,BBLow)<0)
     {
      Alert("������ ����������� ������� ���������� Bollinger Bands - ����� ������:",GetLastError(),"!");
      return;
     }
//--- �������� �������� ���������� ADX ��������� ������
   if(CopyBuffer(ADXHandle,0,0,3,ADX)<0)
     {
      Alert("������ ����������� ������� ���������� ADX - ����� ������:",GetLastError(),"!");
      return;
     }
//--- ������ ����������� �� �������
   double Ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
//--- ������ ����������� �� �������                           
   double Bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
//--- ������
   double pr=0;
//--- �����
   double stop=0,take=0;
//--- ��������� ���������� ���� boolean, ��� ����� �������������� ��� �������� ������� ��� ������� � �������
//--- ������ ������� ������� Bolinger Bands � ��������������� ������
   bool Buy=Ask<BBLow[1] && ADX[1]<ADXLevel && (LastDealType()==0 || LastDealType()==2);
//--- ������ ������ ������� Bolinger Bands � ��������������� ������                             
   bool Sell=Bid>BBUp[1] && ADX[1]<ADXLevel && (LastDealType()==0 || LastDealType()==1);
//--- �������� �� ����� ���  
   if(IsNewBar(_Symbol,0))
     {
      //--- ��� ������� � ������ �� �������
      if(PositionsTotal()<1 && Buy)
        {
         //--- ��������� �����
         if(SL==0)stop=0; else stop=NormalizeDouble(Ask-SL*_Point,_Digits);
         if(TP==0)take=0; else take=NormalizeDouble(Ask+TP*_Point,_Digits);
         //--- ����� ����������� 
         if(Stelth==1) {stop=0;take=0;}
         //--- ��������� ����� �� �������
         trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,Volume(),Ask,stop,take);
         //--- ������ ����������� �����
         if(Stelth==1) PutLable("SL"+DoubleToString(Ask,_Digits),TimeCurrent(),NormalizeDouble(Ask-SL*_Point,_Digits),LableClr);
         if(Stelth==1) PutLable("TP"+DoubleToString(Ask,_Digits),TimeCurrent(),NormalizeDouble(Ask+TP*_Point,_Digits),LableClr);
        }
      //--- ��� ������� � ������ �� �������
      if(PositionsTotal()<1 && Sell)
        {
         //--- ��������� �����
         if(SL==0)stop=0; else stop=NormalizeDouble(Bid+SL*_Point,_Digits);
         if(TP==0)take=0; else take=NormalizeDouble(Bid-TP*_Point,_Digits);
         //--- ����� ����������� 
         if(Stelth==1) {stop=0;take=0;}
         //--- ��������� ����� �� �������
         trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,Volume(),Bid,stop,take);
         if(Stelth==1) PutLable("TP"+DoubleToString(Bid,_Digits),TimeCurrent(),NormalizeDouble(Bid-TP*_Point,_Digits),LableClr);
         if(Stelth==1) PutLable("SL"+DoubleToString(Bid,_Digits),TimeCurrent(),NormalizeDouble(Bid+SL*_Point,_Digits),LableClr);
        }
     }
//--- �������� �� �������
//--- ������� ������� � ����� �����
   if(PositionSelect(_Symbol) && Stelth==1)
     {
      //--- ������� �������
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
        {
         //--- ������� ������
         pr=(Bid-PositionGetDouble(POSITION_PRICE_OPEN))/_Point;
         if(pr>=TP)
           {
            //--- ��������� �������
            trade.PositionClose(_Symbol);
           }
         if(pr<=-SL)
           {
            //--- ��������� �������
            trade.PositionClose(_Symbol);
           }
        }
      //--- ������� �������
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
        {
         //--- ������� ������
         pr=(PositionGetDouble(POSITION_PRICE_OPEN)-Bid)/_Point;
         if(pr>=TP)
           {
            //--- ��������� �������
            trade.PositionClose(_Symbol);
           }
         if(pr<=-SL)
           {
            //--- ��������� �������
            trade.PositionClose(_Symbol);
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| ����������� ����                                                 |
//+------------------------------------------------------------------+
void PutLable(const string name="",datetime time=0,double price=0,const color clr=clrGreen)
  {
//--- ������� �������� ������
   ResetLastError();
//--- ������� �����
   if(!ObjectCreate(0,name,OBJ_ARROW_LEFT_PRICE,0,time,price))
     {
      Print(__FUNCTION__,
            ": �� ������� ������� ����� ������� �����! ��� ������ = ",GetLastError());
      return;
      //--- ��������� ���� �����
      ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
      //--- ��������� ����� ����������� �����
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
      //--- ��������� ������ �����
      ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsNewBar(string symbol,ENUM_TIMEFRAMES timeframe)
  {
//---- ������� ����� ��������� �������� ����
   datetime TNew=datetime(SeriesInfoInteger(symbol,timeframe,SERIES_LASTBAR_DATE));
   datetime m_TOld=0;
//--- �������� �� ��������� ������ ����
   if(TNew!=m_TOld && TNew)
     {
      m_TOld=TNew;
      //--- �������� ����� ���!
      return(true);
      Print("����� ���!");
     }
//--- ����� ����� ���� ���!
   return(false);
  }
//+------------------------------------------------------------------+
//| ������� ��� � ����������� �� ����������� �������                 |
//+------------------------------------------------------------------+
double Volume(void)
  {
   double lot=Lot;
//--- ������� ������ � �������
   HistorySelect(0,TimeCurrent());
//--- ������ � �������
   int orders=HistoryDealsTotal();
//--- ����� ��������� ������  
   ulong ticket=HistoryDealGetTicket(orders-1);
   if(ticket==0)
     {
      Print("��� ������ � �������! ");
      lot=Lot;
     }
//--- ������ ������
   double profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);
//--- ��� ������
   double lastlot=HistoryDealGetDouble(ticket,DEAL_VOLUME);
//--- ������ �������������
   if(profit<0.0)
     {
      //--- ����������� ��������� ���
      lot=lastlot*KLot;
      Print(" C����� ������� �� �����! ");
     }
//--- �������� ��� � ������������
   double minvol=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(lot<minvol)
      lot=minvol;
//--- ���� ��� ������ ������������� �� ��������� ���
   if(lot>MaxLot)
      lot=Lot;
//--- ���������� �������� �����
   return(lot);
  }
//+------------------------------------------------------------------+
//| ������� ��� ��������� �������� ������                            |
//+------------------------------------------------------------------+
int LastDealType(void)
  {
   int type=0;
//--- ������� ������ � �������
   HistorySelect(0,TimeCurrent());
//--- ������ � �������
   int orders=HistoryDealsTotal();
//--- ����� ��������� ������  
   ulong ticket=HistoryDealGetTicket(orders-1);
//--- ��� ������ � �������
   if(ticket==0)
     {
      Print("��� ������ � �������! ");
      type=0;
     }
   if(ticket>0)
     {
      //--- ��������� ������ BUY 
      if(HistoryDealGetInteger(ticket,DEAL_TYPE)==DEAL_TYPE_BUY)
        {
         type=2;
        }
      //--- ��������� ������ SELL
      if(HistoryDealGetInteger(ticket,DEAL_TYPE)==DEAL_TYPE_SELL)
        {
         type=1;
        }
     }
//---
   return(type);
  }
//+------------------------------------------------------------------+
