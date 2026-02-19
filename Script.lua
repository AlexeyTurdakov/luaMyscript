-- ===============================================
--  Версия: v4.0
--  Назначение:
--  Анализ FORTS фьючерсов (SPBFUT)
--  Логика полностью соответствует Excel v1.8
--  Обновление 1 раз в минуту
-- ===============================================


-- ================================
-- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
-- ================================

local CLASS_CODE = "SPBFUT"      -- Класс FORTS фьючерсов
local UPDATE_INTERVAL = 60000    -- Интервал обновления (60000 мс = 1 минута)

local is_run = true              -- Флаг работы скрипта
local tbl = nil                  -- Объект таблицы
local instruments = {}           -- Таблица инструментов
local sc_counter = {}            -- Таблица накопительных счётчиков (аналог столбца S в Excel)


-- ================================
-- ФУНКЦИЯ БЕЗОПАСНОГО ПРЕОБРАЗОВАНИЯ В ЧИСЛО
-- ================================
-- Если значение nil или не число — возвращаем 0
-- Полный аналог Excel функции GetNumberSafe
-- ================================
function to_number_safe(value)

    if value == nil then
        return 0
    end

    local num = tonumber(value)

    if num == nil then
        return 0
    end

    return num
end


-- ================================
-- СОЗДАНИЕ ТАБЛИЦЫ
-- ================================
function create_table()

    tbl = AllocTable()

    AddColumn(tbl, 1, "name", true, QTABLE_STRING_TYPE, 20)
    AddColumn(tbl, 2, "Streight", true, QTABLE_DOUBLE_TYPE, 15)
    AddColumn(tbl, 3, "ScVal", true, QTABLE_INT_TYPE, 10)

    CreateWindow(tbl)
    SetWindowCaption(tbl, "FORTS Signals v4.0")

end


-- ================================
-- ОСНОВНОЙ РАСЧЁТ
-- ================================
function calculate()

    local results = {}

    -- Получаем количество инструментов класса SPBFUT
    local sec_count = getNumberOf("securities")

    for i = 0, sec_count - 1 do

        local sec = getItem("securities", i)

        if sec.class_code == CLASS_CODE then

            local sec_code = sec.sec_code

            -- ================================
            -- Получаем данные стакана
            -- ================================
            local quote = getQuoteLevel2(CLASS_CODE, sec_code)

            if quote ~= nil then

                -- Общий спрос
                local total_bid = to_number_safe(quote.bid_count)

                -- Общие предложения
                local total_offer = to_number_safe(quote.offer_count)

                -- Лучшие заявки
                local bid_qty = 0
                local offer_qty = 0

                if quote.bid ~= nil and quote.bid[1] ~= nil then
                    bid_qty = to_number_safe(quote.bid[1].quantity)
                end

                if quote.offer ~= nil and quote.offer[1] ~= nil then
                    offer_qty = to_number_safe(quote.offer[1].quantity)
                end


                -- ================================
                -- Расчёт T (Streight)
                -- Формула полностью как в Excel:
                -- (общ.спрос / общ.предл + заявки куп. / заявки прод.)
                -- ================================
                local Tval = 0

                if total_offer > 0 and offer_qty > 0 then
                    Tval = (total_bid / total_offer) + (bid_qty / offer_qty)
                end


                -- ================================
                -- Получаем % изменения цены
                -- ================================
                local last = to_number_safe(getParamEx(CLASS_CODE, sec_code, "LAST").param_value)
                local prev_close = to_number_safe(getParamEx(CLASS_CODE, sec_code, "PREVPRICE").param_value)

                local Eval = 0

                if prev_close > 0 then
                    Eval = ((last - prev_close) / prev_close) * 100
                end


                -- ================================
                -- УСЛОВИЕ СИГНАЛА (ТОЧНО КАК В EXCEL)
                -- (T >= 1.999 ИЛИ T <= 0.499)
                -- И
                -- (E >= 2 ИЛИ E <= -2)
                -- ================================
                if (Tval >= 1.999 or Tval <= 0.499)
                   and (Eval >= 2 or Eval <= -2) then

                    -- Увеличиваем накопительный счётчик
                    sc_counter[sec_code] = (sc_counter[sec_code] or 0) + 1

                else
                    -- Сброс если условие нарушено
                    sc_counter[sec_code] = 0
                end


                -- ================================
                -- Фильтр вывода ScVal >= 1
                -- ================================
                if sc_counter[sec_code] ~= nil
                   and sc_counter[sec_code] >= 1 then

                    table.insert(results, {
                        name = sec_code,
                        streight = Tval,
                        scval = sc_counter[sec_code]
                    })

                end

            end

        end

    end


    -- ================================
    -- СОРТИРОВКА ПО УБЫВАНИЮ ScVal
    -- ================================
    table.sort(results, function(a, b)
        return a.scval > b.scval
    end)


    -- ================================
    -- ОЧИСТКА ТАБЛИЦЫ
    -- ================================
    Clear(tbl)


    -- ================================
    -- ЗАПОЛНЕНИЕ ТАБЛИЦЫ
    -- ================================
    for i, item in ipairs(results) do

        InsertRow(tbl, i)

        SetCell(tbl, i, 1, item.name)
        SetCell(tbl, i, 2, string.format("%.3f", item.streight))
        SetCell(tbl, i, 3, tostring(item.scval))

        -- Подсветка зелёным при ScVal >= 3
        if item.scval >= 3 then
            SetColor(tbl, i, 1, RGB(0,255,0), RGB(0,0,0), RGB(0,255,0), RGB(0,0,0))
            SetColor(tbl, i, 2, RGB(0,255,0), RGB(0,0,0), RGB(0,255,0), RGB(0,0,0))
            SetColor(tbl, i, 3, RGB(0,255,0), RGB(0,0,0), RGB(0,255,0), RGB(0,0,0))
        end

    end

end


-- ================================
-- ОСНОВНОЙ ЦИКЛ
-- ================================
function main()

    create_table()

    while is_run do

        calculate()

        sleep(UPDATE_INTERVAL)

    end

end


-- ================================
-- ЗАВЕРШЕНИЕ
-- ================================
function OnStop()

    is_run = false

    if tbl ~= nil then
        DestroyTable(tbl)
    end

end
