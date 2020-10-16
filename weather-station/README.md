# NodeMCU ESP8266 Weather Station kit

## Resources
1. [NodeMCU docs](https://nodemcu.readthedocs.io/en/release/)
2. [same project with raspberry](https://projects.raspberrypi.org/en/projects/build-your-own-weather-station)
3. 

## Hardware used
1. Adafruit NodeMCU Feather HUZZAH with ESP8266
2. The standard 70€ weather kit
3. Adafruit BME680 sensor
4. 220 Ohm resistance
5. RJ11 cables and breakouts


## How to upload code to the device

```nodemcu-tool upload --port=COM4 init.lua credentials.lua sensor.lua```

## Lua F.A.Q.

1. variables are flexible dynamic and global. Things are nil before they exist, tables compain a bit
2. `table` = {`by_name`=`4`, `2`}; `table`.`by_name` `==` `4`; `table[1]` `==` `2` (unnamed keys are indexed starting at 1!) 
3. No `{}`, the equivalent is `do..end` blocks
4. if: `if` `<expr>` `then` `<stmt>` `end`.
5. while: `while` `<expr>` `do` `<stmt>` `end`
6. for: `for` `key`, `val` `in` `pairs`( `<table_expr>` ) `do` `<stmt>` `end`
7. function: `function` (`argument`[, ...]) `<stmt>` `end`

## Caveats

### Non-ending blocks of code

Sometimes `nodemcu-tool` just doesn't upload the whole code (and the interpreter complains for non-ending blocks of code that *do* end).

Try the following:

1. Unplug \& plug the device
2. Open Putty real fast and type `file.remove('init.lua')`
3. Confirm that the console is stable (prompts you: `>` and doesn't print anything)
4. Re-upload code & `init.lua`