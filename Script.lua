-- ===============================================
--  Версия: v4.8
--  Показывает ВСЕ инструменты FORTS
--  Формула корректная
--  Столбцы сокращены
-- ===============================================

local CLASS_CODE = "SPBFUT"
local UPDATE_INTERVAL = 60000

local is_run = true
local tbl = nil
local sc_counter = {}

-------------------------------------------------
function to_number_safe(value)
    if value == nil then return 0 end
    local num = tonumber(value)
    if num == nil then return 0 end
    return num
end

-------------------------------------------------
function create_table()

    tbl = AllocTable()

    AddColumn(tbl, 1, "Наименование", true, QTABLE_STRING_TYPE, 28)
    AddColumn(tbl, 2, "сум.спрос", true, QTABLE_DOUBLE_TYPE, 12)
    AddColumn(tbl, 3, "сум.пред", true, QTABLE_DOUBLE_TYPE, 12)
    AddColumn(tbl, 4, "кол.пок", true, QTABLE_DOUBLE_TYPE, 10)
    AddColumn(tbl, 5, "кол.прод", true, QTABLE_DOUBLE_TYPE, 10)
    AddColumn(tbl, 6, "%изм.", true, QTABLE_DOUBLE_TYPE, 10)
    AddColumn(tbl, 7, "Сила", true, QTABLE_DOUBLE_TYPE, 10)
    AddColumn(tbl, 8, "Счётчик", true, QTABLE_INT_TYPE, 10)

    CreateWindow(tbl)
    SetWindowCaption(tbl, "FORTS Signals v4.8")

end

-------------------------------------------------
function calculate()

    Clear(tbl)

    local row = 1
    local sec_count = getNumberOf("securities")

    for i = 0, sec_count - 1 do

        local sec = getItem("securities", i)

        if sec.class_code == CLASS_CODE then

            local sec_code = sec.sec_code
            local name = sec.short_name .. " [ФОРТС фьючерсы]"

            local total_bid =
                to_number_safe(getParamEx(CLASS_CODE, sec_code, "BIDDEPTHT").param_value)

            local total_offer =
                to_number_safe(getParamEx(CLASS_CODE, sec_code, "OFFERDEPTHT").param_value)

            local num_bids =
                to_number_safe(getParamEx(CLASS_CODE, sec_code, "NUMBIDS").param_value)

            local num_offers =
                to_number_safe(getParamEx(CLASS_CODE, sec_code, "NUMOFFERS").param_value)

            local Eval =
                to_number_safe(getParamEx(CLASS_CODE, sec_code, "PRICEMINUSPREV").param_value)

            -- корректная формула
            local Sila = 0
            if total_offer > 0 and num_offers > 0 then
                Sila = ((total_bid / total_offer) +
                        (num_bids / num_offers)) / 2
            end

            -- условие сигнала
            if (Sila >= 1.999 or Sila <= 0.499)
               and (Eval >= 2 or Eval <= -2) then
                sc_counter[sec_code] =
                    (sc_counter[sec_code] or 0) + 1
            else
                sc_counter[sec_code] = 0
            end

            InsertRow(tbl, row)

            SetCell(tbl, row, 1, name)
            SetCell(tbl, row, 2, tostring(total_bid))
            SetCell(tbl, row, 3, tostring(total_offer))
            SetCell(tbl, row, 4, tostring(num_bids))
            SetCell(tbl, row, 5, tostring(num_offers))
            SetCell(tbl, row, 6, string.format("%.2f", Eval))
            SetCell(tbl, row, 7, string.format("%.3f", Sila))
            SetCell(tbl, row, 8, tostring(sc_counter[sec_code]))

            -- подсветка только при сигнале
            if sc_counter[sec_code] >= 1 then
                for col = 1, 8 do
                    SetColor(tbl, row, col,
                        RGB(0,255,0), RGB(0,0,0),
                        RGB(0,255,0), RGB(0,0,0))
                end
            end

            row = row + 1
        end
    end

end

-------------------------------------------------
function main()

    create_table()

    while is_run do
        calculate()
        sleep(UPDATE_INTERVAL)
    end

end

-------------------------------------------------
function OnStop()

    is_run = false

    if tbl ~= nil then
        DestroyTable(tbl)
    end

end
