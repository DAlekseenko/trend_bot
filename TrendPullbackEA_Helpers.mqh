//+------------------------------------------------------------------+
//|                                      TrendPullbackEA_Helpers.mqh|
//| Вспомогательные функции для TrendPullbackEA                     |
//+------------------------------------------------------------------+

// Функция проверки валидности спреда
// Спред - это разница между ценой покупки (Ask) и ценой продажи (Bid)
bool IsSpreadValid(double maxSpreadPoints)
{
   // Рассчитываем спред в пунктах
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) -
                    SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;

   // Проверяем, что спред не превышает максимально допустимый
   // Большой спред означает высокие комиссии и плохое исполнение ордеров
   return spread <= maxSpreadPoints;
}

// Функция проверки появления нового бара
// Используется для того, чтобы робот работал только один раз на каждой свече
bool IsNewBar(ENUM_TIMEFRAMES tf)
{
   // Статическая переменная хранит время последнего обработанного бара
   // Статическая переменная сохраняет свое значение между вызовами функции
   static datetime lastTime = 0;

   // Получаем время открытия текущего бара на указанном таймфрейме
   datetime current = iTime(_Symbol, tf, 0);

   // Если время изменилось - появился новый бар
   if(current != lastTime)
   {
      lastTime = current; // Сохраняем новое время
      return true;        // Возвращаем true - новый бар появился
   }

   return false; // Время не изменилось - это тот же бар
}

// Функция проверки времени торговли
// Позволяет торговать только в указанном временном диапазоне
bool IsTimeToTrade(int startHour, int endHour)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   int currentHour = dt.hour;
   
   // Если начальный час больше конечного (например, 22-2), значит торговля через полночь
   if(startHour > endHour)
   {
      // Торгуем с StartHour до 23:59 и с 00:00 до EndHour
      return (currentHour >= startHour || currentHour <= endHour);
   }
   else
   {
      // Обычный случай: торговля в пределах одного дня
      return (currentHour >= startHour && currentHour <= endHour);
   }
}

// Функция проверки дня недели для торговли
bool IsDayAllowed(bool tradeMonday, bool tradeTuesday, bool tradeWednesday, bool tradeFriday)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   int dayOfWeek = dt.day_of_week; // 0 = воскресенье, 1 = понедельник, ..., 5 = пятница

   // Проверяем понедельник (day_of_week = 1)
   if(dayOfWeek == 1 && !tradeMonday)
      return false;

   // Проверяем вторник (day_of_week = 2) — убыточный день по анализу
   if(dayOfWeek == 2 && !tradeTuesday)
      return false;

   // Проверяем среду (day_of_week = 3) — самый убыточный день по анализу
   if(dayOfWeek == 3 && !tradeWednesday)
      return false;

   // Проверяем пятницу (day_of_week = 5)
   if(dayOfWeek == 5 && !tradeFriday)
      return false;

   return true;
}

// Функция проверки волатильности (ATR в допустимых пределах)
bool IsVolatilityValid(int atrHandle, double minMultiplier, double maxMultiplier)
{
   double atrBuffer[];
   // Копируем последние 20 значений ATR для расчета среднего
   if(CopyBuffer(atrHandle, 0, 0, 20, atrBuffer) < 20)
      return true; // Если не удалось получить данные - пропускаем проверку
   
   // Рассчитываем средний ATR за период
   double avgATR = 0;
   for(int i = 0; i < 20; i++)
      avgATR += atrBuffer[i];
   avgATR /= 20;
   
   // Текущий ATR
   double currentATR = atrBuffer[0];
   
   // Проверяем, что текущий ATR в допустимых пределах
   double minATR = avgATR * minMultiplier;
   double maxATR = avgATR * maxMultiplier;
   
   return (currentATR >= minATR && currentATR <= maxATR);
}
