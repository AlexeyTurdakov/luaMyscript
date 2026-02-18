-- ============================================================
-- Скрипт анализа дисбаланса спроса/предложения
-- Версия: v1.1
-- Изменение: добавлен сброс ScVal в 0 если хотя бы одно
-- условие не выполняется
-- ============================================================

-- =========================
-- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
-- =========================

local SCRIPT_VERSION = "v1.1"            -- Версия скрипта
local is_run = true                      -- Флаг активности скрипта
local instruments = {}                   -- Таблица инструментов
local ScVal = {}                         -- Таблица счетчиков ScVal для каждого тикера

-- ============================================================
-- БЕЗОПАСНЫЙ ВЫВОД СООБЩЕНИЙ
-- ============================================================

local function safe_message(text)                    -- Функция защищенного вывода
    if text ~= nil then                              -- Проверяем что сообщение существует
        message(tostring(text), 1)                   -- Выводим сообщение в QUIK
    end
end

-- ============================================================
-- ИНИЦИАЛИЗАЦИЯ
-- ============================================================

function OnInit()                                                -- Вызывается при запуске
    
    safe_message("Скрипт запущен. Версия: " .. SCRIPT_VERSION)  -- Сообщение о старте
    
    local classes = getClassesList()                             -- Получаем список классов
    
    if classes == nil or classes == "" then                      -- Проверяем корректность
        safe_message("Ошибка: не удалось получить список классов")
        return
    end
    
    for class_code in string.gmatch(classes, "[^,]+") do         -- Перебираем классы
        
        local sec_list = getClassSecurities(class_code)          -- Получаем список инструментов
        
        if sec_list ~= nil then                                  -- Проверка существования
            
            for sec_code in string.gmatch(sec_list, "[^,]+") do  -- Перебираем тикеры
                
                instruments[#instruments + 1] = {                -- Добавляем инструмент
                    class = class_code,
                    sec = sec_code
                }
                
                ScVal[sec_code] = 0                              -- При первом запуске ВСЕ = 0
                
            end
        end
    end
end

-- ============================================================
-- ОСНОВНОЙ АНАЛИЗ
-- ============================================================

local function analyze_market()
    
    local alert_list = ""                                        -- Строка уведомления
    
    for i, instrument in ipairs(instruments) do
        
        local class = instrument.class
        local sec = instrument.sec
        
        -- Получаем параметры
        
        local bid = getParamEx(class, sec, "BIDDEPTHT")          
        local offer = getParamEx(class, sec, "OFFERDEPTHT")      
        local bid_count = getParamEx(class, sec, "NUMBIDS")      
        local offer_count = getParamEx(class, sec, "NUMOFFERS")  
        local change = getParamEx(class, sec, "LASTCHANGEPRCNT") 
        
        -- Проверяем корректность данных
        
        if not bid or not offer or not bid_count or not offer_count or not change then
            ScVal[sec] = 0                                       -- Если данные некорректны → сброс
            goto continue
        end
        
        local bid_val = tonumber(bid.param_value) or 0
        local offer_val = tonumber(offer.param_value) or 0
        local bid_cnt_val = tonumber(bid_count.param_value) or 0
        local offer_cnt_val = tonumber(offer_count.param_value) or 0
        local change_val = tonumber(change.param_value) or 0
        
        -- Защита от деления на 0
        
        if offer_val == 0 or offer_cnt_val == 0 then
            ScVal[sec] = 0                                       -- Если деление невозможно → сброс
            goto continue
        end
        
        -- Рассчитываем коэффициенты
        
        local ratio_volume = bid_val / offer_val
        local ratio_orders = bid_cnt_val / offer_cnt_val
        
        -- Проверяем выполнение КАЖДОГО условия отдельно
        
        local condition_volume =
            (ratio_volume >= 1.999 or ratio_volume <= 0.499)
        
        local condition_orders =
            (ratio_orders >= 1.999 or ratio_orders <= 0.499)
        
        local condition_change =
            (change_val >= 2 or change_val <= -2)
        
        -- ====================================================
        -- ГЛАВНАЯ ЛОГИКА v1.1
        -- ====================================================
        
        if condition_volume and condition_orders and condition_change then
            ScVal[sec] = ScVal[sec] + 1                          -- Все условия выполнены → +1
        else
            ScVal[sec] = 0                                       -- ХОТЯ БЫ ОДНО не выполнено → сброс
        end
        
        -- Проверяем достижение порога
        
        if ScVal[sec] >= 3 then
            
            local strength = (ratio_volume + ratio_orders) / 2   -- Расчет силы
            
            alert_list = alert_list ..
                sec .. "; " ..
                ScVal[sec] .. "; " ..
                string.format("%.3f", strength) .. "\n"
        end
        
        ::continue::
        
    end
    
    -- Вывод уведомления если есть сигналы
    
    if alert_list ~= "" then
        safe_message("Сигнал обнаружен:\n" .. alert_list)
    end
    
end

-- ============================================================
-- ТРИГГЕР ОБНОВЛЕНИЯ
-- ============================================================

function OnAllTrade()
    if is_run then
        analyze_market()
    end
end

-- ============================================================
-- ОСТАНОВКА
-- ============================================================

function OnStop()
    is_run = false
    safe_message("Скрипт остановлен")
end
