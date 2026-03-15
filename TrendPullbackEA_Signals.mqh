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

   // ИСПРАВЛЕНИЕ: используем правильные цены
   // Для покупки нужна цена Ask (цена покупки)
   // Для продажи нужна цена Bid (цена продажи)
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Рассчитываем расстояние до стоп-лосса на основе ATR
   // ATR показывает волатильность рынка, умножаем на множитель для безопасности
   double slDistance = atr * atrMultiplierSL;

   // Получаем размер пункта для нормализации цен
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // УСЛОВИЕ ДЛЯ ПОКУПКИ:
   // 1. Восходящий тренд (цена выше EMA200 на H1)
   // 2. RSI < 40 (перепродано, значит откат вниз - хорошая точка входа)
   if(trend == TREND_UP && rsi < 40)
   {
      signal.type = ORDER_TYPE_BUY;                    // Тип ордера - покупка
      signal.stopLoss = NormalizeDouble(ask - slDistance, digits);            // Стоп-лосс ниже цены входа (Ask)
      signal.takeProfit = NormalizeDouble(ask + (slDistance * rr), digits);   // Тейк-профит выше цены входа (в 2 раза дальше стоп-лосса)
      signal.isValid = true;                           // Сигнал валидный, можно открывать ордер
      
      if(enableLogging)
         Print("Сигнал на ПОКУПКУ: Ask=", ask, " SL=", signal.stopLoss, " TP=", signal.takeProfit, " RSI=", rsi);
   }

   // УСЛОВИЕ ДЛЯ ПРОДАЖИ:
   // 1. Нисходящий тренд (цена ниже EMA200 на H1)
   // 2. RSI > 60 (перекуплено, значит откат вверх - хорошая точка входа)
   if(trend == TREND_DOWN && rsi > 60)
   {
      signal.type = ORDER_TYPE_SELL;                   // Тип ордера - продажа
      signal.stopLoss = NormalizeDouble(bid + slDistance, digits);             // Стоп-лосс выше цены входа (Bid)
      signal.takeProfit = NormalizeDouble(bid - (slDistance * rr), digits);    // Тейк-профит ниже цены входа (в 2 раза дальше стоп-лосса)
      signal.isValid = true;                            // Сигнал валидный, можно открывать ордер
      
      if(enableLogging)
         Print("Сигнал на ПРОДАЖУ: Bid=", bid, " SL=", signal.stopLoss, " TP=", signal.takeProfit, " RSI=", rsi);
   }

   return signal;
}

// Функция получения текущего значения RSI
double GetRSI(int rsiHandle)
{
   double buffer[];
   // Копируем последнее значение RSI из индикатора
   if(CopyBuffer(rsiHandle, 0, 0, 1, buffer) <= 0)
      return 50; // Если не удалось получить - возвращаем нейтральное значение (50)

   return buffer[0]; // Возвращаем последнее значение RSI (от 0 до 100)
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
