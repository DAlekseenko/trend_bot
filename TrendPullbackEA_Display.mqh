//+------------------------------------------------------------------+
//|                                      TrendPullbackEA_Display.mqh|
//| Модуль отображения информации на графике для TrendPullbackEA    |
//+------------------------------------------------------------------+

// ===================== ПАРАМЕТРЫ ОТОБРАЖЕНИЯ =====================

input bool   ShowInfoPanel = true;      // Показывать информационную панель на графике
input int    InfoPanelX = 10;           // Отступ от левого края (в пикселях)
input int    InfoPanelY = 20;           // Отступ от верхнего края (в пикселях)
input color  TextColor = clrWhite;      // Цвет текста
input int    InfoPanelFontSize = 10;    // Размер шрифта панели
input int    LineSpacing = 16;          // Межстрочный интервал (пиксели)

// Префикс имён объектов (для удаления при деинициализации)
string InfoPanelPrefix = "TPEA_Info_";

// Количество строк в последнем обновлении (для очистки)
int lastLineCount = 0;

// Создание или обновление текстовой метки (OBJ_LABEL) для одной строки
void CreateOrUpdateLabel(long chartId, string name, int x, int y, string text, color clr, int fontSize)
{
   if(ObjectFind(chartId, name) < 0)
   {
      ObjectCreate(chartId, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(chartId, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(chartId, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(chartId, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(chartId, name, OBJPROP_BACK, false);
   }
   ObjectSetInteger(chartId, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(chartId, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(chartId, name, OBJPROP_TEXT, text);
   ObjectSetInteger(chartId, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chartId, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(chartId, name, OBJPROP_FONT, "Consolas");
}

// Отображение многострочного текста на графике через набор OBJ_LABEL объектов
void DisplayInfoText(string text, ulong magicNumber)
{
   long chartId = ChartID();
   string baseName = InfoPanelPrefix + _Symbol + "_" + IntegerToString(magicNumber);

   // Разбиваем текст на строки
   string lines[];
   int lineCount = 0;

   // Ручной парсинг строк (MQL5 StringSplit не всегда доступен)
   string remaining = text;
   while(StringLen(remaining) > 0)
   {
      int pos = StringFind(remaining, "\n");
      if(pos < 0)
      {
         // Последняя строка без перевода
         ArrayResize(lines, lineCount + 1);
         lines[lineCount] = remaining;
         lineCount++;
         break;
      }
      ArrayResize(lines, lineCount + 1);
      lines[lineCount] = StringSubstr(remaining, 0, pos);
      lineCount++;
      remaining = StringSubstr(remaining, pos + 1);
   }

   // Создаём/обновляем метки для каждой строки
   for(int i = 0; i < lineCount; i++)
   {
      string labelName = baseName + "_L" + IntegerToString(i);
      int yPos = InfoPanelY + i * LineSpacing;
      CreateOrUpdateLabel(chartId, labelName, InfoPanelX, yPos, lines[i], TextColor, InfoPanelFontSize);
   }

   // Удаляем лишние строки от предыдущего обновления
   for(int i = lineCount; i < lastLineCount; i++)
   {
      string labelName = baseName + "_L" + IntegerToString(i);
      if(ObjectFind(chartId, labelName) >= 0)
         ObjectDelete(chartId, labelName);
   }

   lastLineCount = lineCount;
   ChartRedraw(chartId);
}

// ===================== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ =====================

datetime lastDayChecked = 0;        // Последний проверенный день
int dailyTrades = 0;                 // Количество сделок за день
double dailyProfit = 0;              // Прибыль за день
int dailyWins = 0;                   // Прибыльных сделок за день
int dailyLosses = 0;                 // Убыточных сделок за день

// Переменные для отслеживания максимальной просадки
double maxEquity = 0;                // Максимальный equity
double maxDrawdown = 0;              // Максимальная просадка
double maxDrawdownPercent = 0;       // Максимальная просадка в процентах

// ===================== ФУНКЦИИ ОТОБРАЖЕНИЯ =====================

// Функция обновления информации на графике
void UpdateInfoPanel(ulong magicNumber, bool enableLogging)
{
   if(!ShowInfoPanel)
   {
      // Удаляем все объекты панели с графика, если панель отключена
      ClearInfoPanel();
      return;
   }

   // Проверяем, начался ли новый день
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime currentDay = StringToTime(IntegerToString(dt.year) + "." +
                                      IntegerToString(dt.mon) + "." +
                                      IntegerToString(dt.day));

   if(currentDay != lastDayChecked)
   {
      // Сбрасываем статистику за день
      dailyTrades = 0;
      dailyProfit = 0;
      dailyWins = 0;
      dailyLosses = 0;
      lastDayChecked = currentDay;
   }

   // Получаем информацию об счете
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
   double marginLevel = 0;
   if(margin > 0)
      marginLevel = equity / margin * 100;

   // Инициализируем максимальный equity при первом запуске
   if(maxEquity == 0)
      maxEquity = equity;

   // Рассчитываем просадку
   double drawdown = balance - equity;
   double drawdownPercent = 0;
   if(balance > 0)
      drawdownPercent = (drawdown / balance) * 100;

   // Рассчитываем максимальную просадку за период
   // Обновляем максимальный equity, если текущий больше
   if(equity > maxEquity)
   {
      maxEquity = equity;
      // Если достигли нового максимума, сбрасываем максимальную просадку
      maxDrawdown = 0;
      maxDrawdownPercent = 0;
   }

   // Рассчитываем текущую просадку от максимума
   double currentDrawdown = maxEquity - equity;
   if(currentDrawdown > maxDrawdown)
   {
      maxDrawdown = currentDrawdown;
      if(maxEquity > 0)
         maxDrawdownPercent = (maxDrawdown / maxEquity) * 100;
   }

   // Получаем статистику по открытым позициям
   int openPositions = 0;
   double openProfit = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == magicNumber)
         {
            openPositions++;
            openProfit += PositionGetDouble(POSITION_PROFIT);
         }
      }
   }

   // Получаем статистику за сегодня из истории
   UpdateDailyStatistics(magicNumber, currentDay);

   // Рассчитываем процент прибыльных сделок за день
   double winRate = 0;
   if(dailyTrades > 0)
      winRate = (double)dailyWins / dailyTrades * 100;

   // Формируем текст для отображения
   string infoText = "";
   infoText += "══════════════════════════════════\n";
   infoText += "  TRENDPULLBACK EA - СТАТИСТИКА\n";
   infoText += "══════════════════════════════════\n";
   infoText += "\n";

   // Информация об счете
   infoText += "СЧЕТ:\n";
   infoText += "  Баланс: $" + DoubleToString(balance, 2) + "\n";
   infoText += "  Средства: $" + DoubleToString(equity, 2) + "\n";
   infoText += "  Свободная маржа: $" + DoubleToString(freeMargin, 2) + "\n";
   infoText += "  Уровень маржи: " + DoubleToString(marginLevel, 2) + "%\n";
   if(marginLevel > 0 && marginLevel < 100)
      infoText += "  НИЗКИЙ УРОВЕНЬ МАРЖИ!\n";
   infoText += "\n";

   // Просадка
   infoText += "ПРОСАДКА:\n";
   infoText += "  Текущая: $" + DoubleToString(drawdown, 2) + " (" + DoubleToString(drawdownPercent, 2) + "%)\n";
   infoText += "  Максимальная: $" + DoubleToString(maxDrawdown, 2) + " (" + DoubleToString(maxDrawdownPercent, 2) + "%)\n";
   if(drawdownPercent > 10)
      infoText += "  ВЫСОКАЯ ПРОСАДКА!\n";
   else if(drawdownPercent > 5)
      infoText += "  Средняя просадка\n";
   else
      infoText += "  Нормальная просадка\n";
   infoText += "\n";

   // Открытые позиции
   infoText += "ОТКРЫТЫЕ ПОЗИЦИИ:\n";
   infoText += "  Количество: " + IntegerToString(openPositions) + "\n";
   infoText += "  Прибыль: $" + DoubleToString(openProfit, 2) + "\n";
   if(openProfit > 0)
      infoText += "  В прибыли\n";
   else if(openProfit < 0)
      infoText += "  В убытке\n";
   else
      infoText += "  В безубытке\n";
   infoText += "\n";

   // Статистика за день
   infoText += "СТАТИСТИКА ЗА ДЕНЬ:\n";
   infoText += "  Сделок: " + IntegerToString(dailyTrades) + "\n";
   infoText += "  Прибыльных: " + IntegerToString(dailyWins) + "\n";
   infoText += "  Убыточных: " + IntegerToString(dailyLosses) + "\n";
   infoText += "  Процент прибыли: " + DoubleToString(winRate, 1) + "%\n";
   infoText += "  Прибыль: $" + DoubleToString(dailyProfit, 2) + "\n";
   if(dailyProfit > 0)
      infoText += "  Прибыльный день\n";
   else if(dailyProfit < 0)
      infoText += "  Убыточный день\n";
   infoText += "\n";

   // Информация о роботе
   infoText += "РОБОТ:\n";
   infoText += "  Символ: " + _Symbol + "\n";
   infoText += "  Magic: " + IntegerToString(magicNumber) + "\n";
   infoText += "  Время: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n";

   // Дополнительная информация
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = (ask - bid) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   infoText += "  Спред: " + DoubleToString(spread, 1) + " пунктов\n";

   infoText += "\n";
   infoText += "══════════════════════════════════\n";

   // Отображаем информацию на графике в верхнем левом углу
   DisplayInfoText(infoText, magicNumber);
}

// Функция обновления статистики за день
void UpdateDailyStatistics(ulong magicNumber, datetime currentDay)
{
   // Получаем историю сделок за сегодня
   datetime startTime = currentDay;
   datetime endTime = currentDay + 86400; // +24 часа

   HistorySelect(startTime, endTime);

   int totalDeals = HistoryDealsTotal();
   dailyTrades = 0;
   dailyProfit = 0;
   dailyWins = 0;
   dailyLosses = 0;

   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      // Проверяем, что это сделка этого робота
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != magicNumber)
         continue;

      // Проверяем, что это закрытие позиции
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      // Получаем прибыль/убыток
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

      dailyTrades++;
      dailyProfit += profit;

      if(profit > 0)
         dailyWins++;
      else if(profit < 0)
         dailyLosses++;
   }
}

// Функция получения общей статистики
string GetTotalStatistics(ulong magicNumber)
{
   // Получаем историю всех сделок этого робота
   datetime startTime = 0; // С начала времен
   datetime endTime = TimeCurrent();

   HistorySelect(startTime, endTime);

   int totalDeals = HistoryDealsTotal();
   int totalTrades = 0;
   int totalWins = 0;
   int totalLosses = 0;
   double totalProfit = 0;
   double maxProfit = 0;
   double maxLoss = 0;

   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != magicNumber)
         continue;

      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

      totalTrades++;
      totalProfit += profit;

      if(profit > 0)
      {
         totalWins++;
         if(profit > maxProfit)
            maxProfit = profit;
      }
      else if(profit < 0)
      {
         totalLosses++;
         if(profit < maxLoss)
            maxLoss = profit;
      }
   }

   double winRate = 0;
   if(totalTrades > 0)
      winRate = (double)totalWins / totalTrades * 100;

   string stats = "\n";
   stats += "═══════════════════════════════════\n";
   stats += "  ОБЩАЯ СТАТИСТИКА\n";
   stats += "═══════════════════════════════════\n\n";
   stats += "Всего сделок: " + IntegerToString(totalTrades) + "\n";
   stats += "Прибыльных: " + IntegerToString(totalWins) + "\n";
   stats += "Убыточных: " + IntegerToString(totalLosses) + "\n";
   stats += "Процент прибыли: " + DoubleToString(winRate, 1) + "%\n";
   stats += "Общая прибыль: $" + DoubleToString(totalProfit, 2) + "\n";
   stats += "Макс. прибыль: $" + DoubleToString(maxProfit, 2) + "\n";
   stats += "Макс. убыток: $" + DoubleToString(maxLoss, 2) + "\n";
   stats += "\n";

   return stats;
}

// Функция очистки информации на графике
void ClearInfoPanel()
{
   Comment("");
   long chartId = ChartID();
   string baseName = InfoPanelPrefix + _Symbol + "_" + IntegerToString(MagicNumber);

   // Удаляем все строки панели
   for(int i = 0; i < lastLineCount; i++)
   {
      string labelName = baseName + "_L" + IntegerToString(i);
      if(ObjectFind(chartId, labelName) >= 0)
         ObjectDelete(chartId, labelName);
   }

   // Также удаляем старые объекты (фон и текст) от предыдущей версии
   if(ObjectFind(chartId, baseName) >= 0)
      ObjectDelete(chartId, baseName);
   if(ObjectFind(chartId, baseName + "_BG") >= 0)
      ObjectDelete(chartId, baseName + "_BG");

   lastLineCount = 0;
   ChartRedraw(chartId);
}
