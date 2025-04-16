import picostdlib
import picostdlib/pico/[stdio, time]
import picostdlib/hardware/[gpio]
import std/math
# simulatore dcf77 
let dcf77SimulatorVer = "0.1.0"

let dataDcf77: array[59, byte] = [
 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, #bit di servizio tutti a zero specie il ptimo.
 0,0,0,1,0,1, #info varie S= 1 sempre
 1,0,1,0,1,0,0,1, #minuti = 15
 0,1,0,0,0,0,1, #ore = 2
 1,1,1,0,0,1, #num giorno mese = 27
 0,1,1, #giorno mese = sabato = 6
 0,1,0,0,1, #mese = dicembre = 12
 1,0,1,0,1,1,1,0,1] #anno = 75
setUpGpio(pinOut, 2, Out); pinOut.pullDown()
pinOut.put(Low)

while true:
  echo("Transmit --> Hour: 2.15  Data: 27/12/2075")
  for dato in dataDcf77:
    if dato == 1:
      pinOut.put(High)
      sleepMs(200)
      pinOut.put(Low)
      sleepMs(800)
    elif dato == 0:
      pinOut.put(High)
      sleepMs(100)
      pinOut.put(Low)
      sleepMs(900)
  sleepMs(1000)

#[ dato trasmesso 000000000000000010110101001010000111100101101001101011101 --> 15.2 27/12/2075 (l'oraio è al contrario prima minuti poi ore
dato reale ore = 2.15
data 27/12/2075 (in relta 1975)]#
