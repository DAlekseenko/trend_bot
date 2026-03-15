//+------------------------------------------------------------------+
//|                                               TrendPullbackEA.mq5|
//| Описание: Expert Advisor для торговли по тренду с входом на откатах
//| Стратегия: Определяет тренд по EMA200 на H1, ищет откаты по RSI на M15
//+------------------------------------------------------------------+
#property strict

// Подключаем библиотеку для работы с торговыми операциями
#include <Trade/Trade.mqh>

// Подключаем модули робота
#include "TrendPullbackEA_Inputs.mqh"    // Параметры входа
#include "TrendPullbackEA_Types.mqh"     // Типы данных и структуры
#include "TrendPullbackEA_Trend.mqh"     // Определение тренда
#include "TrendPullbackEA_Signals.mqh"   // Генерация сигналов
#include "TrendPullbackEA_Risk.mqh"      // Управление рисками
#include "TrendPullbackEA_Helpers.mqh"   // Вспомогательные функции
#include "TrendPullbackEA_Trade.mqh"     // Исполнение сделок (последний, т.к. использует другие модули)
#include "TrendPullbackEA_Display.mqh"  // Отображение информации на графике

// Объект для выполнения торговых операций
CTrade trade;

// ===================== GLOBAL HANDLES ==============================
// Хэндлы (идентификаторы) индикаторов, которые создаются при инициализации

int emaHandle; // Хэндл индикатора EMA (экспоненциальная скользящая средняя)
int rsiHandle; // Хэндл индикатора RSI (индекс относительной силы)
int atrHandle; // Хэндл индикатора ATR (средний истинный диапазон)

// ===================== INITIALIZATION ==============================
// Функция инициализации робота - вызывается один раз при запуске

int OnInit()
{
   // Создаем индикатор EMA на таймфрейме H1 (часовой график)
   // Используется для определения общего направления тренда
   emaHandle = iMA(_Symbol, PERIOD_H1, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   // Создаем индикатор RSI на таймфрейме M15 (15-минутный график)
   // Используется для поиска точек входа на откатах
   rsiHandle = iRSI(_Symbol, PERIOD_M15, RSIPeriod, PRICE_CLOSE);
   
   // Создаем индикатор ATR на таймфрейме M15
   // Используется для расчета волатильности и размера стоп-лосса
   atrHandle = iATR(_Symbol, PERIOD_M15, ATRPeriod);

   // Проверяем, что все индикаторы созданы успешно
   // Если хотя бы один не создан - робот не запустится
   if(emaHandle == INVALID_HANDLE ||
      rsiHandle == INVALID_HANDLE ||
      atrHandle == INVALID_HANDLE)
   {
      Print("Ошибка создания индикаторов!");
      return(INIT_FAILED);
   }

   // Устанавливаем магический номер для всех ордеров этого робота
   // Это позволяет отличать ордера этого робота от других
   trade.SetExpertMagicNumber(MagicNumber);
   
   // Инициализируем панель информации
   if(ShowInfoPanel)
   {
      UpdateInfoPanel(MagicNumber, EnableLogging);
   }
   
   if(EnableLogging)
      Print("TrendPullbackEA инициализирован успешно. Символ: ", _Symbol, " Magic: ", MagicNumber);

   return(INIT_SUCCEEDED);
}

// ===================== MAIN LOOP ==================================
// Главная функция, которая вызывается при каждом тике (изменении цены)

void OnTick()
{
   // ОБНОВЛЕНИЕ ИНФОРМАЦИИ НА ГРАФИКЕ
   // Обновляем панель информации на каждом тике
   UpdateInfoPanel(MagicNumber, EnableLogging);
   
   // УПРАВЛЕНИЕ ОТКРЫТЫМИ ПОЗИЦИЯМИ
   // Трейлинг стоп - обновляем стоп-лоссы открытых позиций
   if(UseTrailingStop)
   {
      ManageTrailingStop(atrHandle, MagicNumber, TrailingStopATR, TrailingStepATR, EnableLogging, trade);
   }
   
   // Break-even стоп - переводим стоп-лосс в безубыток при достижении прибыли
   if(UseBreakEven)
   {
      ManageBreakEven(atrHandle, MagicNumber, BreakEvenRR, ATRMultiplierSL, EnableLogging, trade);
   }

   // Проверка: работаем только на новом баре M15 (15-минутном)
   // Это предотвращает множественные входы в одну и ту же свечу
   if(!IsNewBar(PERIOD_M15))
      return;

   // ЗАЩИТА ОТ СЕРИИ УБЫТКОВ: проверяем, можно ли торговать
   if(UseLossProtection && !CheckLossProtection(MagicNumber, MaxConsecutiveLosses, PauseAfterLossHours, EnableLogging))
      return;

   // ФИЛЬТР ПО ВРЕМЕНИ: проверяем, можно ли торговать в текущее время
   if(UseTimeFilter && !IsTimeToTrade(StartHour, EndHour))
      return;
   
   // ФИЛЬТР ПО ДНЯМ НЕДЕЛИ: проверяем, разрешена ли торговля в этот день
   if(!IsDayAllowed(TradeMonday, TradeFriday))
      return;

   // Проверка спреда: если спред слишком большой - не торгуем
   // Большой спред означает высокие комиссии и плохое исполнение
   if(!IsSpreadValid(MaxSpreadPoints))
      return;

   // УЛУЧШЕННАЯ ПРОВЕРКА: если уже есть открытая позиция этого робота - выходим
   // Проверяем по MagicNumber, а не просто по символу
   if(HasOpenPosition(MagicNumber))
      return;

   // Определяем направление тренда на основе EMA200 на часовом графике
   TrendDirection trend = GetTrend(emaHandle);

   // Если тренд не определен (боковик) - не торгуем
   // Стратегия работает только в трендовых условиях
   if(trend == TREND_FLAT)
      return;
   
   // ФИЛЬТР СИЛЫ ТРЕНДА: проверяем, достаточно ли сильный тренд
   if(UseTrendStrength && !IsTrendStrong(emaHandle, MinPriceDistanceEMA))
   {
      if(EnableLogging)
         Print("Тренд слишком слабый. Торговля пропущена.");
      return;
   }

   // Получаем текущее значение RSI для поиска отката
   double rsi = GetRSI(rsiHandle);
   
   // Получаем текущее значение ATR для расчета стоп-лосса
   double atr = GetATR(atrHandle);

   // Проверка: если ATR некорректный - не торгуем
   if(atr <= 0)
      return;
   
   // ФИЛЬТР ВОЛАТИЛЬНОСТИ: проверяем, что волатильность в допустимых пределах
   if(UseVolatilityFilter && !IsVolatilityValid(atrHandle, MinATRMultiplier, MaxATRMultiplier))
   {
      if(EnableLogging)
         Print("Волатильность вне допустимых пределов. Торговля пропущена.");
      return;
   }

   // Генерируем торговый сигнал на основе тренда, RSI и ATR
   TradeSignal signal = GenerateSignal(trend, rsi, atr, RR, ATRMultiplierSL, EnableLogging);

   // Если сигнал не валидный (не выполнены условия входа) - выходим
   if(!signal.isValid)
      return;

   // Рассчитываем размер лота на основе процента риска и расстояния до стоп-лосса
   double lot = CalculateLot(signal.stopLoss, signal.type, RiskPercent, EnableLogging);

   // ПРОВЕРКА: если рассчитанный лот меньше минимального - не открываем позицию
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lot < minLot)
   {
      if(EnableLogging)
         Print("Лот слишком мал: ", lot, " < ", minLot, ". Позиция не открыта.");
      return;
   }

   // Выполняем торговую операцию (открываем ордер)
   ExecuteTrade(signal, lot, trade, EnableLogging);
}

// ===================== DEINITIALIZATION ===========================
// Функция деинициализации робота - вызывается при остановке

void OnDeinit(const int reason)
{
   // Очищаем информацию на графике
   ClearInfoPanel();
   
   // Освобождаем ресурсы индикаторов
   if(emaHandle != INVALID_HANDLE)
      IndicatorRelease(emaHandle);
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   
   if(EnableLogging)
      Print("TrendPullbackEA деинициализирован. Причина: ", reason);
}
