# DCF77 signal simulator for PR2040

This simple library, simulates the signal received from the DCF77, or rather simulates the exit of the commercial reception modules. For now it is necessary to have two RP2040 microcontrollers, to make the simulation.
In this version (0.1.0) the transmitted signal is:
Minute = 15
hour = 2 (am)
Number of the Day = 27
Day of the week = 6 (Saturday)
Month = 12 (December)
Year = (20)75 (Only the last two digits of the year are transmitted therefore by convention 2075)
The rough byte sent is:
```
000000000000000010110101001010000111100101101001101011101
```
In the next versions you could do it "programmable by the user".
