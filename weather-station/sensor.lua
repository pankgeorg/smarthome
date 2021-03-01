waterCapacity = 0.274 -- mm per click
delayuS = 1000000 -- Set delay in microSecond. here 1 second
windCount = 0 -- Wind clicks
latestWind = tmr.now() -- Wind timer
waterCount = 0 -- Water clicks
latestWater = tmr.now() -- Water timer
latestDeg = 0 -- Latest +
voltageReadings = 1000
now = tmr.now()
gustSpeed = 0
windSpeed = 0

function read_voltage()
    local c = 0
    local s = 0
    while (c < voltageReadings) do
        c = c + 1
        s = s + adc.read(0)
    end
    local reading = s / c - 5
    --print(s, c,  reading)
    tmr.delay(1000) -- timer Delay
    return reading
end

do
    waterVolume = 0
    local pin, pulse1, du = 5, 0, 0 -- pin14 (14==5)
    gpio.mode(pin, gpio.INT, gpio.PULLUP)
    local function pin14water(level, pulse2)
        if (level == 0) then
            return
        end
        waterCount = waterCount + 1
        diff = (pulse2 > pulse1) and (pulse2 - pulse1) or (2 ^ 31 + pulse2 - pulse1)
        du = diff * 0.000001 + 0.001
        waterVolume = 0.274 * 3600 / du
        print("water, du =", waterCount, ", ", du)
        pulse1 = pulse2
        gpio.trig(pin, level == gpio.HIGH and "down" or "up")
    end
    gpio.trig(pin, "down", pin14water)
end

do
    windSpeed = 0
    local pin, pulse1, du = 6, 0, 0 -- pin12 (14==5)
    gpio.mode(pin, gpio.INT, gpio.PULLUP)
    local function pin12wind(level, pulse2)
        if (level == 0) then
            return
        end
        windCount = windCount + 1
        diff = (pulse2 > pulse1) and (pulse2 - pulse1) or (2 ^ 31 + pulse2 - pulse1)
        du = diff * 0.000001 + 0.001
        windSpeed = math.max(2.4 / du, windSpeed) -- This will be the max gust speed between HTTP calls
        print("wind ", windSpeed, ", du ", du)
        pulse1 = pulse2
        gpio.trig(pin, level == gpio.HIGH and "down" or "up")
    end
    gpio.trig(pin, "down", pin12wind)
end

delayuS = 1000000 -- Set delay in microSecond. here 1 second

alt = 150 -- altitude of the measurement place

sda, scl = 1, 2
i2c.setup(0, sda, scl, i2c.SLOW) -- call i2c.setup() only once
tmr.delay(100000)
-- Oversamplings

-- 0    Skipped (output set to 0x80000)
-- 1    oversampling ×1
-- 2    oversampling ×2
-- 3    oversampling ×4
-- 4    oversampling ×8
-- 5    oversampling ×16

-- temp, pressure, humidity, heater_temp, heater_duration, IIR_coeff, cold_start
s = bme680.setup()
tmr.delay(delayuS)
tmr.delay(delayuS)
if s == nil then
    print("Sensor not initialized")
    tmr.delay(60 * delayuS)
    node.restart()
end
-- delay calculated by formula provided by Bosch: 121 ms, minimum working (empirical): 150 ms

function read_bme680()
    T, P, H, G, QNH, Tsgn = 0, 0, 0, 0, 0, 1
    T, P, H, G, QNH = bme680.read(alt)
    tmr.delay(1000)
    if T then
        Tsgn = (T < 0 and -1 or 1)
        T = Tsgn * T
        print(string.format("T=%s%d.%02d", Tsgn < 0 and "-" or "", T / 100, T % 100))
        print(string.format("QFE=%d.%03d", P / 100, P % 100))
        print(string.format("QNH=%d.%03d", QNH / 100, QNH % 100))
        print(string.format("humidity=%d.%03d%%", H / 1000, H % 1000))
        print(string.format("gas resistance=%d", G))
        D = bme680.dewpoint(H, T)
        Dsgn = (D < 0 and -1 or 1)
        D = Dsgn * D
        print(string.format("dew_point=%s%d.%02d", Dsgn < 0 and "-" or "", D / 100, D % 100))
    end
end

function voltage_to_deg(vin)
    min = 2000
    min_i = 1
    voltage = {600, 310, 190, 50, 10, 20, 30, 90}
    degrees = {0, 45, 90, 135, 180, 225, 270, 315}
    for i, v in pairs(voltage) do
        if math.abs(vin - v) < math.abs(vin - min) then
            min = v
            min_i = i
        end
    end
    print(degrees[min_i])
    return degrees[min_i]
end

function read_all()
    now = tmr.now()
    bme680.startreadout(300, read_bme680)
    V = read_voltage()
    tmr.delay(10000)
    if T == nil then
        return
    end
    temp = string.format("%s%d.%02d", Tsgn < 0 and "-" or "", T / 100, T % 100)
    pres = string.format("%d.%03d", P / 100, P % 100)
    gasr = string.format("%d", G)
    dewp = string.format("%s%.2f", Dsgn < 0 and "-" or "", D / 100)
    humd = string.format("%.3f", H / 1000)
    gustSpeed = windSpeed
    diff = (now > latestWind) and (now - latestWind) or (2 ^ 31 + now - latestWind)
    du = diff * 0.000001 + 0.001
    windAverage = 2.4 * windCount / du
    waterAverage = waterVolume * waterCount / ((now - latestWater) / 3600)
    latestDeg = voltage_to_deg(V)
    print("temp ", temp)
    print("pres ", pres)
    print("gasr ", gasr)
    print("dewp ", dewp)
    print("gust ", gustSpeed)
    print("humd ", humd)
    print("degr ", latestDeg)
    print("wind ", windAverage)
    print("wndc ", windCount)
    print("watr ", waterCount)
    print("now  ", now / (1000 * 1000))
    print("prev ", latestWater / (1000 * 1000))

    url =
        "http://api.pankgeorg.com/station-readings?s=ESP8266%20Georgia%20Panagiotis%20Psychiko" ..
        string.format("&temp=%s", temp or "") ..
            string.format("&pres=%s", pres or "") ..
                string.format("&gasr=%s", gasr or "") ..
                    string.format("&gust=%s", gustSpeed or "") ..
                        string.format("&humd=%s", humd or "") ..
                            string.format("&degr=%d", latestDeg or "") ..
                                string.format("&wind=%d", windAverage or "") ..
                                    string.format("&wndc=%d", windCount or "") ..
                                        string.format("&watr=%d", waterCount or "") ..
                                            string.format("&now=%.3f", now / (1000 * 1000)) ..
                                                string.format("&prev=%.3f", latestWater / (1000 * 1000))

    http.get(
        url,
        nil,
        function(code, data)
            if (code < 0) then
                print("HTTP request failed")
            else
                print(code, data)
                latestWater = now
                waterCount = 0
                latestWind = now
                windCount = 0
                windSpeed = 0
            end
        end
    )
end

globalTimer =
    tmr.create():alarm(
    30000,
    tmr.ALARM_AUTO,
    function()
        read_all()
    end
)

print("Loaded sensor.lua")
