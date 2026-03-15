//+------------------------------------------------------------------+
//|                                       TrendPullbackEA_Signals.mqh|
//| Функции генерации торговых сигналов для TrendPullbackEA        |
//+------------------------------------------------------------------+

// ===================== SIGNAL GENERATION ===========================
// Функция генерации торгового сигнала на основе тренда, RSI и ATR

TradeSignal GenerateSignal(TrendDirection trend, double rsi, double atr, double rr, double atrMultiplierSL, bool enableLogging)
{
   // Инициализируем структуру сигнала
   TradeSignal signal;
   signal.isValid = false; // По умолчанию сигнал невалидный

   // Для покупки нужна цена Ask, для продажи — цена Bid
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Рассчитываем расстояние до стоп-лосса на основе ATR
   double slDistance = atr * atrMultiplierSL;

   // Получаем размер пункта для нормализации цен
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // Получаем предыдущее значение RSI для проверки пересечения уровня
   double prevRSI = GetPrevRSI(rsiHandle);

   // УСЛОВИЕ ДЛЯ ПОКУПКИ:
   // 1. Восходящий тренд (цена выше EMA200 на H1)
   // 2. RSI пересёк уровень 40 снизу вверх (prevRSI < 40 И текущий RSI >= 40)
   //    Это означает выход из зоны перепроданности — подтверждение разворота отката
   if(trend == TREND_UP && prevRSI < 40 && rsi >= 40)
   {
      signal.type = ORDER_TYPE_BUY;
      signal.stopLoss = NormalizeDouble(ask - slDistance, digits);
      signal.takeProfit = NormalizeDouble(ask + (slDistance * rr), digits);
      signal.isValid = true;

      if(enableLogging)
         Print("Сигнал на ПОКУПКУ (RSI пересёк 40 снизу): Ask=", ask, " SL=", signal.stopLoss, " TP=", signal.takeProfit, " RSI=", rsi, " prevRSI=", prevRSI);
   }

   // УСЛОВИЕ ДЛЯ ПРОДАЖИ:
   // 1. Нисходящий тренд (цена ниже EMA200 на H1)
   // 2. RSI пересёк уровень 60 сверху вниз (prevRSI > 60 И текущий RSI <= 60)
   //    Это означает выход из зоны перекупленности — подтверждение разворота отката
   if(trend == TREND_DOWN && prevRSI > 60 && rsi <= 60)
   {
      signal.type = ORDER_TYPE_SELL;
      signal.stopLoss = NormalizeDouble(bid + slDistance, digits);
      signal.takeProfit = NormalizeDouble(bid - (slDistance * rr), digits);
      signal.isValid = true;

      if(enableLogging)
         Print("Сигнал на ПРОДАЖУ (RSI пересёк 60 сверху): Bid=", bid, " SL=", signal.stopLoss, " TP=", signal.takeProfit, " RSI=", rsi, " prevRSI=", prevRSI);
   }

   return signal;
}

// Функция получения текущего значения RSI (бар 1 — последний закрытый бар)
double GetRSI(int rsiHandle)
{
   double buffer[];
   // Копируем значение RSI с бара 1 (последний закрытый бар)
   if(CopyBuffer(rsiHandle, 0, 1, 1, buffer) <= 0)
      return 50; // Если не удалось получить — возвращаем нейтральное значение

   return buffer[0];
}

// Функция получения предыдущего значения RSI (бар 2 — для определения пересечения уровня)
double GetPrevRSI(int rsiHandle)
{
   double buffer[];
   // Копируем значение RSI с бара 2 (предпоследний закрытый бар)
   if(CopyBuffer(rsiHandle, 0, 2, 1, buffer) <= 0)
      return 50; // Если не удалось получить — возвращаем нейтральное значение

   return buffer[0];
}

// Функция получения текущего значения ATR
double GetATR(int atrHandle)
{
   double buffer[];
   // Копируем последнее значение ATR из индикатора
   if(CopyBuffer(atrHandle, 0, 0, 1, buffer) <= 0)
      return 0; // Если не удалось получить - возвращаем 0

   return buffer[0]; // Возвращаем последнее значение ATR (волатильность в пунктах)
}
