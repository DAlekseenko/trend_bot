//+------------------------------------------------------------------+
//|                                         TrendPullbackEA_Risk.mqh|
//| Функции управления рисками для TrendPullbackEA                  |
//+------------------------------------------------------------------+

// ===================== RISK MANAGER ================================
// Функция расчета размера лота на основе процента риска от баланса
// Это критически важная функция для управления рисками!

double CalculateLot(double stopLossPrice, ENUM_ORDER_TYPE orderType, double riskPercent, bool enableLogging)
{
   // Получаем текущий баланс счета
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   // Рассчитываем сумму денег, которую мы готовы рисковать на этой сделке
   // Например, при балансе $1000 и RiskPercent = 1.0, riskAmount = $10
   double riskAmount = balance * (riskPercent / 100.0);

   // ИСПРАВЛЕНИЕ: используем правильную цену входа в зависимости от типа ордера
   double price;
   if(orderType == ORDER_TYPE_BUY)
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // Для покупки - цена Ask
   else
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);  // Для продажи - цена Bid
   
   // Рассчитываем расстояние от цены входа до стоп-лосса в пунктах
   double stopDistance = MathAbs(price - stopLossPrice);
   
   // Защита от нулевого или отрицательного расстояния
   if(stopDistance <= 0)
   {
      if(enableLogging)
         Print("Ошибка: расстояние до стоп-лосса <= 0");
      return 0;
   }

   // Получаем стоимость одного тика и размер тика для данного инструмента
   // Эти значения нужны для правильного расчета размера лота
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   // Защита от нулевых значений
   if(tickValue <= 0 || tickSize <= 0)
   {
      if(enableLogging)
         Print("Ошибка: некорректные значения tickValue или tickSize");
      return 0;
   }

   // Формула расчета лота:
   // lot = риск_в_деньгах / (расстояние_стоп_лосса_в_тиках * стоимость_тика)
   // Это гарантирует, что при срабатывании стоп-лосса мы потеряем ровно riskAmount
   double lot = riskAmount / (stopDistance / tickSize * tickValue);

   // Получаем ограничения брокера по размеру лота
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);  // Минимальный лот
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);  // Максимальный лот
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP); // Шаг изменения лота

   // Ограничиваем размер лота минимальным и максимальным значениями брокера
   lot = MathMax(minLot, MathMin(maxLot, lot));
   
   // Нормализуем размер лота под шаг брокера (например, если шаг 0.01, то 0.123 -> 0.12)
   lot = NormalizeDouble(lot / lotStep, 0) * lotStep;

   return lot;
}
