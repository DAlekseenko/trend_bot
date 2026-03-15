//+------------------------------------------------------------------+
//|                                          TrendPullbackEA_Inputs.mqh|
//| Файл с параметрами входа для TrendPullbackEA                    |
//+------------------------------------------------------------------+

// ===================== INPUT PARAMETERS ===========================
// Параметры, которые можно настроить в настройках робота

// Основные параметры стратегии
input double RiskPercent      = 0.75; // Процент риска от баланса на одну сделку (снижен для уменьшения влияния комиссий)
input int    EMAPeriod        = 200;  // Период экспоненциальной скользящей средней для определения тренда
input int    RSIPeriod        = 14;   // Период индикатора RSI для поиска откатов
input double RR               = 2.0;  // Соотношение риск/прибыль (Risk/Reward). Например, 2.0 означает, что тейк-профит в 2 раза больше стоп-лосса
input int    ATRPeriod        = 14;   // Период индикатора ATR для расчета волатильности
input double ATRMultiplierSL  = 1.5;  // Множитель ATR для расчета расстояния стоп-лосса (стоп-лосс = ATR * 1.5)
input double MaxSpreadPoints  = 30;   // Максимально допустимый спред в пунктах (если спред больше - сделка не открывается)
input ulong  MagicNumber      = 777;  // Уникальный номер для идентификации ордеров этого робота

// Дополнительные параметры
input bool   UseTimeFilter    = true;  // Использовать фильтр по времени торговли (включен по результатам анализа)
input int    StartHour        = 10;    // Начало торговли (час, 0-23) — прибыльные часы 10-17
input int    EndHour          = 17;    // Конец торговли (час, 0-23) — убыточные часы исключены
input bool   UseTrailingStop  = true; // Использовать трейлинг стоп
input double TrailingStopATR  = 1.0;   // Множитель ATR для трейлинг стопа
input double TrailingStepATR  = 0.5;   // Шаг трейлинг стопа в ATR
input bool   EnableLogging    = true;  // Включить логирование операций

// Улучшения для стабильной торговли
input bool   UseTrendStrength = true;  // Использовать фильтр силы тренда
input double MinPriceDistanceEMA = 50; // Минимальное расстояние цены от EMA в пунктах
input bool   UseVolatilityFilter = false; // Фильтр волатильности
input double MinATRMultiplier = 0.5;  // Минимальный ATR (от среднего за период)
input double MaxATRMultiplier = 2.0;   // Максимальный ATR (от среднего за период)
input bool   UseLossProtection = true; // Защита от серии убытков
input int    MaxConsecutiveLosses = 3;  // Максимальное количество убытков подряд
input int    PauseAfterLossHours = 24;   // Пауза в часах после серии убытков
input bool   UseBreakEven = false;      // Использовать break-even стоп
input double BreakEvenRR = 1.0;         // При достижении прибыли 1x от риска - в безубыток
input bool   TradeMonday = true;        // Торговля в понедельник
input bool   TradeTuesday = false;      // Торговля во вторник (отключен — убыточный день по анализу)
input bool   TradeWednesday = false;    // Торговля в среду (отключен — самый убыточный день по анализу)
input bool   TradeFriday = true;        // Торговля в пятницу
