# DCF77 signal simulator for PR2040

This simple library, simulates the signal received from the DCF77, or rather simulates the exit of the commercial reception modules. For now it is necessary to have two RP2040 microcontrollers, to make the simulation.
In this version (0.1.0) the transmitted signal is:
```
Minute = 15
hour = 2 (am)
Number of the Day = 27
Day of the week = 6 (Saturday)
Month = 12 (December)
Year = (20)75 (Only the last two digits of the year are transmitted therefore by convention 2075)
```
The rough byte sent is:
```
000000000000000010110101001010000111100101101001101011101
```
With the 0.2.0 version you can set your date to be sent. just use the procedure
# dcf.putData()
If used without parameters, the default value is transmitted. If, on the other hand, enter the parameters transmits the date you want. es:
dcf.putData(pe=false, mi=30, ho=20, dy=5, wd=1, mo=7, ye=25)
where:
```
pe = period of the year (indeed = / summer =)
mi = minute (0.. 59)
ho = hour (0..24)
dy = number of the day (1..31)
wd = day of the week (1= Monday..... 7= Sunday)
mo = mounth (1 = January .... 12 =Dicember)
ye = year (last two number; es 2025 = 25 only) -- 2000 + 25!
```
