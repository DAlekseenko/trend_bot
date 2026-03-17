//+------------------------------------------------------------------+
//|                                        TrendPullbackEA_Trade.mqh|
//| Модуль исполнения сделок и управления позициями                   |
//+------------------------------------------------------------------+

// ===================== ИСПОЛНЕНИЕ СДЕЛОК ============================

// Функция открытия торговой позиции
// Использует данные из структуры TradeSignal для открытия Buy или Sell ордера
void ExecuteTrade(TradeSignal &signal, double lot, CTrade &trade, bool enableLogging)
{
   bool result = false;

   if(signal.type == ORDER_TYPE_BUY)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      result = trade.Buy(lot, _Symbol, ask, signal.stopLoss, signal.takeProfit, "TrendPullbackEA BUY");
   }
   else if(signal.type == ORDER_TYPE_SELL)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      result = trade.Sell(lot, _Symbol, bid, signal.stopLoss, signal.takeProfit, "TrendPullbackEA SELL");
   }

   if(enableLogging)
   {
      if(result)
         Print("Ордер открыт успешно. Тип: ", (signal.type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
               " Лот: ", lot, " SL: ", signal.stopLoss, " TP: ", signal.takeProfit);
      else
         Print("Ошибка открытия ордера. Код: ", GetLastError());
   }
}

// ===================== ПРОВЕРКА ОТКРЫТЫХ ПОЗИЦИЙ ====================

// Проверка наличия открытой позиции с указанным магическим номером
bool HasOpenPosition(ulong magicNumber)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == (long)magicNumber)
            return true;
      }
   }
   return false;
}

// ===================== ТРЕЙЛИНГ СТОП ================================

// Управление трейлинг стопом на основе ATR
// Перемещает стоп-лосс вслед за ценой, сохраняя расстояние на основе ATR
void ManageTrailingStop(int atrHandle, ulong magicNumber, double trailingATR, double trailingStepATR, bool enableLogging, CTrade &trade)
{
   // Получаем текущее значение ATR
   double atrBuffer[];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
      return;

   double atr = atrBuffer[0];
   double trailDistance = atr * trailingATR;    // Расстояние трейлинг стопа
   double stepDistance  = atr * trailingStepATR; // Минимальный шаг перемещения

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)magicNumber) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      long posType = PositionGetInteger(POSITION_TYPE);

      if(posType == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double newSL = NormalizeDouble(bid - trailDistance, digits);

         // Перемещаем SL только вверх и только если шаг достаточный
         if(newSL > currentSL + stepDistance && newSL > openPrice)
         {
            if(!trade.PositionModify(ticket, newSL, currentTP))
            {
               if(enableLogging)
                  Print("Ошибка трейлинг стопа BUY. Код: ", GetLastError());
            }
            else if(enableLogging)
               Print("Трейлинг стоп BUY: SL перемещён на ", newSL);
         }
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double newSL = NormalizeDouble(ask + trailDistance, digits);

         // Перемещаем SL только вниз и только если шаг достаточный
         if((currentSL == 0 || newSL < currentSL - stepDistance) && newSL < openPrice)
         {
            if(!trade.PositionModify(ticket, newSL, currentTP))
            {
               if(enableLogging)
                  Print("Ошибка трейлинг стопа SELL. Код: ", GetLastError());
            }
            else if(enableLogging)
               Print("Трейлинг стоп SELL: SL перемещён на ", newSL);
         }
      }
   }
}

// ===================== БЕЗУБЫТОК ====================================

// Перемещение стоп-лосса в безубыток при достижении определённой прибыли
// breakEvenRR — коэффициент от расстояния риска, при котором SL переносится в безубыток
void ManageBreakEven(int atrHandle, ulong magicNumber, double breakEvenRR, double atrMultiplierSL, bool enableLogging, CTrade &trade)
{
   // Получаем текущее значение ATR для расчёта расстояния риска
   double atrBuffer[];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
      return;

   double atr = atrBuffer[0];
   double riskDistance = atr * atrMultiplierSL;  // Расстояние стоп-лосса (размер риска)
   double beDistance = riskDistance * breakEvenRR; // Расстояние прибыли для активации безубытка

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)magicNumber) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      long posType = PositionGetInteger(POSITION_TYPE);

      if(posType == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         // Прибыль достигла уровня безубытка, а SL ещё ниже цены открытия
         if(bid >= openPrice + beDistance && currentSL < openPrice)
         {
            double newSL = NormalizeDouble(openPrice + _Point, digits); // SL чуть выше цены открытия
            if(!trade.PositionModify(ticket, newSL, currentTP))
            {
               if(enableLogging)
                  Print("Ошибка безубытка BUY. Код: ", GetLastError());
            }
            else if(enableLogging)
               Print("Безубыток BUY: SL перемещён на ", newSL, " (цена открытия: ", openPrice, ")");
         }
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         // Прибыль достигла уровня безубытка, а SL ещё выше цены открытия
         if(ask <= openPrice - beDistance && (currentSL > openPrice || currentSL == 0))
         {
            double newSL = NormalizeDouble(openPrice - _Point, digits); // SL чуть ниже цены открытия
            if(!trade.PositionModify(ticket, newSL, currentTP))
            {
               if(enableLogging)
                  Print("Ошибка безубытка SELL. Код: ", GetLastError());
            }
            else if(enableLogging)
               Print("Безубыток SELL: SL перемещён на ", newSL, " (цена открытия: ", openPrice, ")");
         }
      }
   }
}

// ===================== ЗАЩИТА ОТ СЕРИИ УБЫТКОВ =====================

// Проверка серии убытков из истории сделок
// Возвращает true если торговля разрешена, false если нужно приостановить
bool CheckLossProtection(ulong magicNumber, int maxLosses, int pauseHours, bool enableLogging)
{
   // Запрашиваем историю сделок за последние 30 дней
   datetime fromTime = TimeCurrent() - 30 * 24 * 3600;
   datetime toTime = TimeCurrent();

   if(!HistorySelect(fromTime, toTime))
      return true; // Если не удалось получить историю — разрешаем торговлю

   int totalDeals = HistoryDealsTotal();
   int consecutiveLosses = 0;
   datetime lastLossTime = 0;

   // Перебираем сделки с конца (от последних к первым)
   for(int i = totalDeals - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      // Проверяем, что сделка принадлежит этому роботу
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)magicNumber) continue;

      // Проверяем, что это закрытие позиции
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

      if(profit < 0)
      {
         consecutiveLosses++;
         // Запоминаем время последнего убытка в серии
         if(lastLossTime == 0)
            lastLossTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      }
      else
      {
         // Встретили прибыльную сделку — серия убытков прервана
         break;
      }
   }

   // Если серия убытков достигла лимита — проверяем паузу
   if(consecutiveLosses >= maxLosses)
   {
      datetime resumeTime = lastLossTime + pauseHours * 3600;
      if(TimeCurrent() < resumeTime)
      {
         if(enableLogging)
            Print("Защита от убытков: ", consecutiveLosses, " убытков подряд. ",
                  "Пауза до ", TimeToString(resumeTime, TIME_DATE|TIME_MINUTES));
         return false; // Торговля запрещена
      }
   }

   return true; // Торговля разрешена
}
