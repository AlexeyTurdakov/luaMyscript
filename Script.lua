-- ===============================================
--  Версия: v4.9
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
function get_trade_date()

    local d = getInfoParam("TRADEDATE")
    if not d then return nil end

    local day   = tonumber(string.sub(d,1,2))
    local month = tonumber(string.sub(d,4,5))
    local year  = tonumber(string.sub(d,7,10))

    return {year=year, month=month, day=day}
end

-------------------------------------------------
function get_days_to_expiry(sec_code)

    local info = getSecurityInfo(CLASS_CODE, sec_code)
    if not info or not info.mat_date then return 0 end

    local mat = tostring(info.mat_date)
    if string.len(mat) ~= 8 then return 0 end

    local exp_year  = tonumber(string.sub(mat,1,4))
    local exp_month = tonumber(string.sub(mat,5,6))
    local exp_day   = tonumber(string.sub(mat,7,8))

    local trade = get_trade_date()
    if not trade then return 0 end

    local expiry_time = os.time({
        year=exp_year,
        month=exp_month,
        day=exp_day,
        hour=0
    })

    local trade_time = os.time({
        year=trade.year,
        month=trade.month,
        day=trade.day,
        hour=0
    })

    local diff = math.floor((expiry_time - trade_time) / 86400)

    return diff
end

-------------------------------------------------
function create_table()

    tbl = AllocTable()

    AddColumn(tbl, 1, "Наименование", true, QTABLE_STRING_TYPE, 28)
    AddColumn(tbl, 2, "До погашения", true, QTABLE_INT_TYPE, 12)
    AddColumn(tbl, 3, "сум.спрос", true, QTABLE_DOUBLE_TYPE, 12)
    AddColumn(tbl, 4, "сум.пред", true, QTABLE_DOUBLE_TYPE, 12)
    AddColumn(tbl, 5, "кол.пок", true, QTABLE_DOUBLE_TYPE, 10)
    AddColumn(tbl, 6, "кол.прод", true, QTABLE_DOUBLE_TYPE, 10)
    AddColumn(tbl, 7, "%изм.", true, QTABLE_DOUBLE_TYPE, 10)
    AddColumn(tbl, 8, "Сила", true, QTABLE_DOUBLE_TYPE, 10)
    AddColumn(tbl, 9, "Счётчик", true, QTABLE_INT_TYPE, 10)

    CreateWindow(tbl)
    SetWindowCaption(tbl, "FORTS Signals v4.9")

end

-------------------------------------------------
function request_lastchange()

    local sec_count = getNumberOf("securities")

    for i = 0, sec_count - 1 do
        local sec = getItem("securities", i)

        if sec.class_code == CLASS_CODE
           and string.find(sec.short_name, "-") ~= nil then

            ParamRequest(CLASS_CODE, sec.sec_code, "LASTCHANGE")
        end
    end
end

-------------------------------------------------
function calculate()

    Clear(tbl)

    local row = 1
    local sec_count = getNumberOf("securities")

    for i = 0, sec_count - 1 do

        local sec = getItem("securities", i)

        if sec.class_code == CLASS_CODE
           and string.find(sec.short_name, "-") ~= nil then

            local sec_code = sec.sec_code
            local name = sec.short_name .. " [ФОРТС фьючерсы]"

            local days = get_days_to_expiry(sec_code)

            if days >= 1 then

                local total_bid =
                    to_number_safe(getParamEx(CLASS_CODE, sec_code, "BIDDEPTHT").param_value)

                local total_offer =
                    to_number_safe(getParamEx(CLASS_CODE, sec_code, "OFFERDEPTHT").param_value)

                local num_bids =
                    to_number_safe(getParamEx(CLASS_CODE, sec_code, "NUMBIDS").param_value)

                local num_offers =
                    to_number_safe(getParamEx(CLASS_CODE, sec_code, "NUMOFFERS").param_value)

                local Eval = 0

                local p = getParamEx(CLASS_CODE, sec_code, "LASTCHANGE")

                if p and p.result == "1" then
                    Eval = tonumber(p.param_value) or 0
                else
                    local last =
                        to_number_safe(getParamEx(CLASS_CODE, sec_code, "LAST").param_value)

                    local prev =
                        to_number_safe(getParamEx(CLASS_CODE, sec_code, "PREVPRICE").param_value)

                    if prev > 0 then
                        Eval = ((last - prev) / prev) * 100
                    end
                end

                local Sila = 0
                if total_offer > 0 and num_offers > 0 then
                    Sila = ((total_bid / total_offer) +
                            (num_bids / num_offers)) / 2
                end

                if (Sila >= 1.999 or Sila <= 0.499)
                   and (Eval >= 2 or Eval <= -2) then
                    sc_counter[sec_code] =
                        (sc_counter[sec_code] or 0) + 1
                else
                    sc_counter[sec_code] = 0
                end

                -- ВЫВОД ТОЛЬКО ЕСЛИ СЧЁТЧИК >= 3
                if sc_counter[sec_code] >= 3 then

                    InsertRow(tbl, row)

                    SetCell(tbl, row, 1, name)
                    SetCell(tbl, row, 2, tostring(days))
                    SetCell(tbl, row, 3, tostring(total_bid))
                    SetCell(tbl, row, 4, tostring(total_offer))
                    SetCell(tbl, row, 5, tostring(num_bids))
                    SetCell(tbl, row, 6, tostring(num_offers))
                    SetCell(tbl, row, 7, string.format("%.2f", Eval))
                    SetCell(tbl, row, 8, string.format("%.3f", Sila))
                    SetCell(tbl, row, 9, tostring(sc_counter[sec_code]))

                    for col = 1, 9 do
                        SetColor(tbl, row, col,
                            RGB(0,255,0), RGB(0,0,0),
                            RGB(0,255,0), RGB(0,0,0))
                    end

                    row = row + 1
                end
            end
        end
    end
end

-------------------------------------------------
function main()

    create_table()
    request_lastchange()

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
