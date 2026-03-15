//+------------------------------------------------------------------+
//|                                         TrendPullbackEA_Trend.mqh|
//| Функции определения тренда для TrendPullbackEA                   |
//+------------------------------------------------------------------+

// ===================== TREND DETECTOR ==============================
// Функция определения направления тренда на основе EMA200

TrendDirection GetTrend(int emaHandle)
{
   // Массив для хранения значений EMA
   double emaBuffer[];
   
   // Копируем последнее значение EMA из индикатора
   // Если не удалось скопировать - возвращаем неопределенный тренд
   if(CopyBuffer(emaHandle, 0, 0, 1, emaBuffer) <= 0)
      return TREND_FLAT;

   // Получаем цену закрытия последней свечи на часовом графике
   double price = iClose(_Symbol, PERIOD_H1, 0);

   // Если цена выше EMA - восходящий тренд
   if(price > emaBuffer[0])
      return TREND_UP;

   // Если цена ниже EMA - нисходящий тренд
   if(price < emaBuffer[0])
      return TREND_DOWN;

   // Если цена равна EMA (маловероятно, но возможно) - боковик
   return TREND_FLAT;
}

// Функция проверки силы тренда (расстояние цены от EMA)
bool IsTrendStrong(int emaHandle, double minDistance)
{
   double emaBuffer[];
   if(CopyBuffer(emaHandle, 0, 0, 1, emaBuffer) <= 0)
      return false;
   
   double price = iClose(_Symbol, PERIOD_H1, 0);
   double distance = MathAbs(price - emaBuffer[0]);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Переводим расстояние в пункты
   double distancePoints = distance / point;
   
   return distancePoints >= minDistance;
}
