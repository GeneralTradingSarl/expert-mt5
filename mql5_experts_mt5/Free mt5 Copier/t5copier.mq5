/*
MIT License

Copyright (c) [year] [fullname]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/
#define server_flags FILE_WRITE|FILE_SHARE_WRITE|FILE_SHARE_READ|FILE_COMMON|FILE_BIN
#define client_flags FILE_READ|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_COMMON|FILE_BIN
#define program MQLInfoString(MQL_PROGRAM_NAME)
//---
//#define _debug

//--- this definition enables my custom libraries. No point in enabling if you don't have the files.
//#define _nostd
//+------------------------------------------------------------------+
//|              Mt5 Standard library headers                        |
//+------------------------------------------------------------------+
#ifdef _nostd	// Use custom libraries
#include <main/trade.mqh>
CTrade m_trade;
CPosition m_position;
#else	// Use standard libraries that come with the default terminal installation
#include <Trade/Trade.mqh>
CTrade m_trade;
CPositionInfo m_position;
#endif
//---  program running modes.
enum Mode {Server, Client};
//---
sinput group "=== settings ===";
sinput Mode program_mode = Server;  // Application program_mode.
sinput string server_id = "LetCashFlow"; // Server identifier.(Unique per server instance)
sinput double copy_factor = 100; // Copy factor (100% means copy as is)
sinput int max_slippage = 20;   // Maximum slippage
sinput bool no_try = true;  // Do not open m_trade if slippage is large?
//--- store corresponding received ticket with opened one, to track closing
struct pair_ticket {
    ulong             sr_ticket, cl_ticket;
                     pair_ticket(void):
                     sr_ticket(0), cl_ticket(0) {};
};
//---
static int fhandle = INVALID_HANDLE;
const string fname = "Server++/" + server_id;
ulong hash_at_connection = NULL;
ulong open_tickets[], expired_tickets[];
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
    if(program_mode == Server) {
        if(FileIsExist("Server++/delete", FILE_COMMON))
            if(!FileDelete("Server++/delete", FILE_COMMON)) {
                Alert("Server error!");
                return 97;
            }
        if(FileIsExist(fname, FILE_COMMON))
            if(!FileDelete(fname, FILE_COMMON)) {
                Alert(StringFormat("Please terminate the server instance at [%s] and try again!", server_id));
                return 98;
            }
        //---
        fhandle = FileOpen(fname, server_flags);
        if(fhandle == INVALID_HANDLE) {
            Alert(StringFormat("Failed setting up server at address [%s]", server_id));
            return 99;
        }
    } else {
        if(FileIsExist("Server++/delete", FILE_COMMON))
            if(!FileDelete("Server++/delete", FILE_COMMON)) {
                Alert("Server error!");
                return 100;
            }
        int error = 0;
        if(!reconnect(server_id, error))
            return error;
    }
    Alert(StringFormat("%s launched successfully!", EnumToString(program_mode)));
    if(program_mode == Client)
        EventSetTimer(1);
//---
    return 0;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Comment("");
    FileClose(fhandle);
    Print(StringFormat("%s shutting down...", EnumToString(program_mode)));
    if(program_mode == Server)
        if(!FileDelete(fname, FILE_COMMON)) {
            if(reason == REASON_INITFAILED)
                FileDelete(fname, FILE_COMMON);
            int del = FileOpen("Server++/delete", FILE_BIN | FILE_COMMON | FILE_WRITE);
            if(del == INVALID_HANDLE) {
                Alert("Server abnormal shutdown!\nClear common folder.");
                return;
            }
            FileWriteDouble(del, 3.142);
            FileFlush(del);
            FileClose(del);
            printf("Preparing termination of clients...");
            printf("%s shutdown successfull.",  EnumToString(program_mode));
            return;
        }
    if(program_mode == Client) {
        if(reason == REASON_INITFAILED)
            return;
        FileDelete(fname, FILE_COMMON);
        printf("%s shutdown successfull.", EnumToString(program_mode));
    }
    return;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
struct Data {
    int               type;
    double            lotsize, sl, tp;
    ulong             ticket, leverage, hash;
    double            open_price, equity, close_price;
    uchar             symbol[8];
    //---
                     Data(void): ticket(0), lotsize(0.0), sl(0.0),
                     tp(0.0), open_price(0.0), leverage(0), equity(0.0),
                     close_price(0.0) {
        ArrayInitialize(symbol, NULL);
    }
};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick(void) {
    if(program_mode == Server)
        return;
    if(!TradeAllowed())
        return;
//---
    if(len(to_open) > 0 || len(to_close) > 0)
        retry();
//---   check if server is active
    int error = NULL;
    if(program_mode == Client)
        if(FileIsExist("Server++/delete", FILE_COMMON)) {
            Alert("Server disconnected!");
            ExpertRemove();
            return;
        }
//--- run client loop
    if(program_mode == Server)
        return;
//---
    Data dt;
    int data_size = sizeof(Data);
    FileReadStruct(fhandle, dt, data_size);
    const string sym = CharArrayToString(dt.symbol, 0, 8) + StringSubstr(Symbol(), 6);
    if(len(sym) >= 6)
        if(!SymbolSelect(sym, true))
            Alert(StringFormat("Symbol [%s] not selected in marketwatch!", sym));
    if(dt.ticket == 0)
        return;
//---
#ifdef _debug
    string open_msg, close_msg;
    open_msg = StringFormat("Server: [%s]\nLeverage: %d\nTicket: "
                            "%d\nSymbol: %s\nVolume: %f\nType: %s\n"
                            "SL: %f\nTP: %f\nOpenPrice: %f",
                            server_id, dt.leverage, dt.ticket, sym,
                            dt.lotsize, dt.type == 1 ? "Buy" : dt.type == -1 ?
                            "Sell" : "Close", dt.sl, dt.tp, dt.open_price);
    close_msg = StringFormat("Server: [%s]\nType: %s\nTicket: %d\nPrice: %f",
                             server_id, "***Close***", dt.ticket, dt.close_price);
    if(dt.type != 0)
        Comment(open_msg);
    else
        Comment(close_msg);
#endif
//---
    static bool init = false;
    if(!init) {
        m_trade.SetDeviationInPoints(max_slippage * 2);
        m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
        init = true;
    }
//---
    MqlTick tick;
    tick.ask = 0.0;
    tick.bid = 0.0;
    if(len(sym) >= 6)
        if(!SymbolInfoTick(sym, tick))
            Alert("Price refresh error!");
    static pair_ticket p[];
    double lots_normalized = 0.0;
    if(dt.type != 0)
        lots_normalized = NormalizeDouble(((AccountInfoDouble(ACCOUNT_EQUITY)
                                            * dt.lotsize) / dt.equity) * (copy_factor > 0 ? copy_factor / 100 : 1.0), 2);
    lots_normalized = VerifyLots(lots_normalized, sym);
//---
    switch(dt.type) {
    case 1: {
        if(!m_trade.Buy(lots_normalized, sym, tick.ask))
            if(m_trade.ResultRetcode() == TRADE_RETCODE_REQUOTE)
                if(no_try) {
                    Alert(StringFormat("Failed buy ticket %d [requote]", dt.ticket));
                    return;
                } else {
                    dt.lotsize = lots_normalized;
                    append(to_open, dt);
                    return;
                }
        pair_ticket d;
        d.sr_ticket = dt.ticket;
        d.cl_ticket = m_trade.ResultOrder();
        append(open_tickets, d.cl_ticket);
        append(p, d);
        return;
    }
    case -1: {
        if(!m_trade.Sell(lots_normalized, sym, tick.bid))
            if(m_trade.ResultRetcode() == TRADE_RETCODE_REQUOTE)
                if(no_try) {
                    Alert(StringFormat("Failed sell ticket %d [requote]", dt.ticket));
                    return;
                } else {
                    dt.lotsize = lots_normalized;
                    append(to_open, dt);
                    return;
                }
        pair_ticket d;
        d.sr_ticket = dt.ticket;
        d.cl_ticket = m_trade.ResultOrder();
        append(open_tickets, d.cl_ticket);
        append(p, d);
        return;
    }
    default: {
        ulong ticket = 0;
        for(int i = 0; i < len(p); i++)
            if(p[i].sr_ticket == dt.ticket) {
                ticket = p[i].cl_ticket;
                if(ticket == 0)
                    return;
                ArrayRemove(p, i, 1);
                if(!m_trade.PositionClose(ticket) ||
                        m_trade.ResultRetcode() != TRADE_RETCODE_DONE)
                    append(to_close, ticket);
            }
        return;
    }
    }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Data to_open[];
ulong to_close[];
//---
void retry(void) {
    if(len(to_close))
        while(len(to_close))
            if(m_trade.PositionClose(to_close[len(to_close) - 1], max_slippage * 10))
                if(m_trade.ResultRetcode() == TRADE_RETCODE_DONE)
                    pop(to_close, to_close[len(to_close) - 1]);
    if(len(to_open))
        while(len(to_open)) {
            int idx = len(to_open) - 1;
            string sym = CharArrayToString(to_open[idx].symbol, 0, 8);
            MqlTick tick;
            tick.ask = 0.0;
            tick.bid = 0.0;
            if(len(sym) >= 6)
                if(!SymbolInfoTick(sym, tick))
                    Alert("Prices refresh error");
            switch(to_open[idx].type) {
            case 1: {
                if(m_trade.Buy(to_open[idx].lotsize, sym, tick.ask, to_open[idx].sl, to_open[idx].tp))
                    if(m_trade.ResultRetcode() == TRADE_RETCODE_DONE) {
                        ulong ticket = m_trade.ResultOrder();
                        append(open_tickets, ticket);
                        ArrayRemove(to_open, idx, 1);
                    }
                break;
            }
            case -1: {
                if(m_trade.Sell(to_open[idx].lotsize, sym, tick.bid, to_open[idx].sl, to_open[idx].tp))
                    if(m_trade.ResultRetcode() == TRADE_RETCODE_DONE) {
                        ulong ticket = m_trade.ResultOrder();
                        append(open_tickets, ticket);
                        ArrayRemove(to_open, idx, 1);
                    }
                break;
            }
            }
        }
//---
    return;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer() {
    if(TradeAllowed())
        OnTick();
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
    if(program_mode == Client)
        return;
    if(result.order == 0 || request.type > 1)
        return;
    if(request.position == 0) {
        if(!m_position.SelectByTicket(request.order))
            return;
        Data s;
        //---
        s.lotsize = request.volume;
        s.open_price = result.price;
        s.sl = request.sl;
        s.ticket = request.order;
        s.tp = request.tp;
        s.leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
        s.equity = AccountInfoDouble(ACCOUNT_EQUITY);
        s.type = request.type == ORDER_TYPE_BUY ? 1 : -1;
        StringToCharArray(request.symbol, s.symbol, 0, 8);
        //---
        if(FileWriteStruct(fhandle, s, sizeof(Data)) < sizeof(Data))
            Alert("Server write error!");
        FileFlush(fhandle);
    }
    if(request.position != 0) {
        Data s;
        s.type = 0;
        s.ticket = request.position;
        s.close_price = result.price;
        if(FileWriteStruct(fhandle, s, sizeof(Data)) < sizeof(Data))
            Alert("Server write error!");
        FileFlush(fhandle);
    }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//|                      Utility Tools                               |
//+------------------------------------------------------------------+
template <typename t>
bool append(t &array[], const t &element) {
    int size = len(array);
    int reserved = 0;
    if(size % 10 == 0)
        reserved = 10;
    if(ArrayResize(array, size + 1, reserved) <= 0)
        return false;
    array[size] = element;
    return true;
}
//---
template <typename t>
bool pop(t &array[], const t element) {
    int counter = len(array);
    while(counter) {
        int idx = present(array, element);
        if(idx == -1)
            break;
        ArrayRemove(array, idx, 1);
        --counter;
    }
    return present(array, element) == -1;
}
//---
template <typename t>
int present(const t &array[], const t element) {
    for(int i = 0; i < len(array); i++)
        if(array[i] == element)
            return i;
    return -1;
}
//---
template <typename t>
int len(const t &array[]) {
    return ArraySize(array);
}
//---
int len(const string var) {
    return StringLen(var);
}
//---
double VerifyLots(const double variable, const string &sym) {
    double volume = NormalizeDouble(variable, 2);
    double lots_step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
    if(lots_step > 0.0)
        volume = lots_step * MathFloor(volume / lots_step);
    double lots_min = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
    if(volume < lots_min)
        volume = lots_min;
    double lots_max = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
    if(volume > lots_max)
        volume = lots_max;
    return(volume);
}
//---
bool TradeAllowed(void) {
    return AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) &&
           AccountInfoInteger(ACCOUNT_TRADE_EXPERT) &&
           TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
           TerminalInfoInteger(TERMINAL_CONNECTED);
}
//---
bool reconnect(const string sr_id, int &err) {
    if(program_mode != Client)
        return false;
    if(!FileIsExist(fname, FILE_COMMON)) {
        Alert(StringFormat("No server at specified address [%s]!", server_id));
        err = 100;
        return false;
    }
    if(FileIsExist("Server++/delete", FILE_COMMON))
        return false;
    fhandle = FileOpen(fname, client_flags);
    if(fhandle == INVALID_HANDLE) {
        Alert(StringFormat("Failed setting up client at address [%s]", server_id));
        err = 101;
        return false;
    }
    if(FileSize(fhandle) > 0)
        if(!FileSeek(fhandle, 0, SEEK_END)) {
            Alert("Server error!");
            err = 102;
            return false;
        }
    return true;
}
//+------------------------------------------------------------------+
