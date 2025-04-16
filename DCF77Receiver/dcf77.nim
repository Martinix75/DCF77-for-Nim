import picostdlib
import picostdlib/pico/[time, stdio]
import picostdlib/hardware/[gpio]
import std/[strformat, math]

let dcf77Ver* = "0.4.0" #bit informativi lettura e funzioni orari data.

type 
  DCF77* = object
    pinIn: Gpio #pin di ascolto
    minute: uint8 #minuti
    hour: uint8
    day: uint8
    weekday: uint8 
    month: uint8
    year: uint8 # anno solo ultime cifre quindi 2000+ numero
    a1: uint8 # va a 1 un ora priam del cambio orario (ver0.3.0).
    cest: uint8 #ORARIO ESTIVO: 1 durante l'orario estivo (0 in quello invernale ver0.3.0). ex Z1
    cet: uint8 #ORARIO INVERNALE: 1 durante l'orario invernale (0 in quello estivo ver0.3.0)). ex Z2.
    dataRaw: array[59, byte] #contiene i bit ricevuti da dcf77
    countElement: uint8 = 0 #contattore elementi inseriti inarrai dati (zero gia messo.
    antiFalseStart:bool = false #anti partenza falsa con segnale gia in salita.
    minuteMarker: bool = false # false se aappena partita o non rivelato il silenzi di inixio tx, true se rilvato inixio tx.
    timeCount: uint64 #variabile unica per il conto dei secondi impulsi/silenzio (Ver 0.3.0).
    dataRedy: bool = false #dice se è stato riempito l'array con i dati (true) o no (false).
    parity: bool = false #bit per vedre se la parita dei dati è corretta true =ok; false = errore(ver0.3.0).
    engagedSignal: bool = false #flag per vedre se il segnale è stato trovato (ver0.3.0)

var 
  dcf77Ref: ref DCF77 = nil #variabile puntatore per poter usare DCF// dentro la callbck.
# ------- Pubblic Procs Protipe -------
proc initDCF77*(pin: int):ref DCF77
proc resetDCF77*(self: ref DCF77)
proc receiveDCF77*(self: ref DCF77)
proc isReadyDcf77*(self: ref DCF77):bool
proc decodeDCF77*(self: ref DCF77)
proc getMinute*(self: ref DCF77): uint8
proc getHour*(self: ref DCF77): uint8
proc getDay*(self: ref DCF77): uint8
proc getWeekDay*(self: ref DCF77): uint8
proc getMonth*(self: ref DCF77): uint8
proc getYear*(self: ref DCF77): uint8
proc isCest*(self: ref DCF77): bool
# ----- End Pubblic Procs Protipe -----

# ------- Private Procs Protipe -------
proc readDCF77Signal(pin: Gpio; events: uint32) {.cdecl.}
proc decodeBCD(self: ref DCF77; data: openArray[byte]):uint8
proc checkParity(self: ref DCF77)
proc readDataRow(self: ref DCF77): array[59, byte]
# ----- End Private Procs Protipe -----

# ----- Private Proc -------------------------------------------------------
proc readDCF77Signal(pin: Gpio; events: uint32) {.cdecl.} =
  if dcf77Ref[].countElement < 59: #fa la lettura solo se l'arrai è vuoto o si vule rifare la lettura forzata.
    if dcf77Ref == nil:
      return
    if dcf77Ref[].minuteMarker == false:
      dcf77Ref[].engagedSignal = false #se il segnale NON è stato trovato e NON è validato.(ver0.3.0)
      #echo("---> Attendo segnale...")
      if events == 4:
        dcf77Ref[].timeCount = timeUs64()
        dcf77Ref[].antiFalseStart = true
      elif (events == 8) and (dcf77Ref[].antiFalseStart == true):
        dcf77Ref[].timeCount = timeUs64() - dcf77Ref[].timeCount
        #echo(fmt"zertime: {dcf77Ref[].timeCount}")
        if dcf77Ref[].timeCount >= 1_500_000:#tempo sufficiente per capire che inizia nuova sequanza dati.
          dcf77Ref[].minuteMarker = true
    else:
      #echo("Dato Valido..")
      #dataRaw[0] = 0
      dcf77Ref[].engagedSignal = true #se il segnale è stato trovato e validato
      if events == 8:
        dcf77Ref[].timeCount = timeUs64()
      elif events == 4:
        dcf77Ref[].timeCount = timeUs64() - dcf77Ref[].timeCount
        #echo(fmt"Durata Impulso: {dcf77Ref[].timeCount div 1000}")
        if dcf77Ref[].timeCount >= 80_000 and dcf77Ref[].timeCount <= 140_000: #se impulso comreso tar i tempi = 0.
          dcf77Ref[].dataRaw[dcf77Ref[].countElement] = 0 
        elif dcf77Ref[].timeCount >= 150_000 and dcf77Ref[].timeCount <= 240_000:#se impulso comreso tar i tempi = 1.
          dcf77Ref[].dataRaw[dcf77Ref[].countElement] = 1
        dcf77Ref[].countElement.inc() #iuncrementa il contattore (max 59 posizioni!!!!
        if dcf77Ref[].countElement == 59:
          dcf77Ref.checkParity() #controlla la parita dei dati.
          if dcf77Ref[].parity == true:
            echo("Parity OK")
            dcf77Ref[].dataRedy = true
          else:
            echo("Parity ERROR")
            dcf77Ref[].dataRedy = false
          #echo("Basta dati!!")
        else:
          dcf77Ref[].dataRedy = false
        echo(fmt"Array Dati: {dcf77Ref.dataRaw}")
        #dcf77Ref.checkParity()

proc readDataRow(self: ref DCF77): array[59, byte] = #ritorna l'array grezzo (solo uso interno/ debug Ver 0.2.0)
  result = dcf77Ref[].dataRaw

proc checkParity(self: ref DCF77) =
  echo("Controllo parita")
  var 
    parity_minute_bit: uint8 = 0
    parity_hour_bit: uint8 = 0
    pariti_year_bit: uint8 = 0
    parity_array: array[3, byte]
  let
    parity_minute = self.dataRaw[28]
    parity_hour = self.dataRaw[35]
    parity_data = self.dataRaw[58]
  for val in self.dataRaw[21..27]:
    if val == 1:
      parity_minute_bit = parity_minute_bit xor 1
  parityArray[0] = parity_minute_bit
  for val in self.dataRaw[29..34]:
    if val == 1:
      parity_hour_bit = parity_hour_bit xor 1
  parityArray[1] = parity_hour_bit
  for val in self.dataRaw[36..57]:
    if val == 1:
      pariti_year_bit = pariti_year_bit xor 1
  parityArray[2] = pariti_year_bit
  if parity_array[0] == parity_minute and parity_array[0] == parity_hour and parity_array[0] == parity_data:
    self.parity = true
  else:
    self.parity = false
  echo(fmt"Arry Locale: {parity_array}")
  echo(fmt"Parita OK --> {self.parity}")

proc decodeBCD(self: ref DCF77; data: openArray[byte]):uint8 = #decodifica i dati BCD in unumeri decimali (ver0.2.0).
  #echo ("DecodificaBCD")
  let bcd_value = [1.byte, 2, 4, 8, 10, 20, 40, 80]
  for index in 0..len(data)-1:
    result = result + (data[index] * bcd_value[index])
# ----- Private Proc END ---------------------------------------------------

# ----- PUbblic Proc -------------------------------------------------------
proc initDCF77*(pin: int):ref DCF77 = #ritorna il puntatore a dcf77 (ver020).
  let pin_init = pin.Gpio; pin_init.setDir(In); pin_init.pullDown()
  #result = DCF77(pinIn: pin_init)
  new(result)
  result.pinIn = pin_Init
  dcf77Ref = result

proc receiveDCF77*(self: ref DCF77) = #prende il puntatore e dcf77(ver02.0).
  echo("Lettrua Dati dcf77...")
  self.resetDCF77()
  setIrqEnabledWithCallback(self.pinIn, {EdgeRise, EdgeFall}, true, readDCF77Signal)

proc isReadyDcf77*(self: ref DCF77):bool = #se i l'array è riempito con tutti i dati ritorna TRUE (Ver0.2.0).
  result = dcf77Ref[].dataRedy

proc decodeDCF77*(self: ref DCF77) = #alal chiamata converte i  vari valori BCD in valore decimali (ver 0.2.0).
  if self.isReadyDcf77 == true and self.parity == true: #codifica solo se l'array è valido.
    self.minute = self.decodeBCD(self.dataRaw[21..27])
    self.hour = self.decodeBCD(self.dataRaw[29..34])
    self.day = self.decodeBCD(self.dataRaw[36..41])
    self.month = self.decodeBCD(self.dataRaw[45..49])
    self.year = self.decodeBCD(self.dataRaw[50..57])
    self.cet = self.dataRaw[17]
    self.cest = self.dataRaw[18]
  else:
    echo("Decode Failed")

proc resetDCF77*(self: ref DCF77) = #resetta i valori per uan huova lettura del dcf77 (ver0.3.0).
  self.countElement = 0 
  self.antiFalseStart = false 
  self.minuteMarker = false 
  self.dataRedy = false 
  self.parity = false 
  self.engagedSignal = false 
  self. timeCount = 0
  for index in 0..len(self.dataRaw)-1:
    self.dataRaw[index] = 0 #porto a zero l'intero array per sicurezza.

proc getMinute*(self: ref DCF77): uint8 = #ritrona i minuti ricevuti via dfc77 (ver0.4.0).
  result = self.minute

proc getHour*(self: ref DCF77): uint8 = #ritorna le ore ricevute via dcf77 (ver 0.4.0).
  result = self.hour

proc getDay*(self: ref DCF77): uint8 = #ritorna il giorno del mese (1..31) ricevuto dal dvf77(ver0.4.0).
  result = self.day

proc getWeekDay*(self: ref DCF77): uint8 = #ritorna la giornta della settimana (1..7 ver 0.4.0).
  result = self.weekday

proc getMonth*(self: ref DCF77): uint8 = #ritorna il mese ricevuto dal dcf77 (1..12 ver0.4.0).
  result = self.month
  
proc getYear*(self: ref DCF77): uint8 = #ritorna l'anno (ultime 2 cifre ver 0.4.0).
  result = self.year

proc isCest*(self: ref DCF77): bool = #dice se siamo nell'orario estivo o invernale TRUE Cest estivo (ver 0.4.0).
  if self.cest == 1 and self.cet == 0: #orario estivo.
    result = true
  elif self.cest == 0 and self.cet == 1: #orariuo invernale.
    result = false
# ----- PUbblic Proc END -----------------------------------------------------
  
when isMainModule:
  stdioInitAll()
  sleepMs(1500)
  echo("Init DCF77..")
  let dcf = initDCF77(15)
  var stampa = false
  dcf.receiveDCF77()
  while true:
    if dcf.isReadyDcf77 == true and dcf.engagedSignal == true:
      #echo(fmt"Dati --> {dcf.readDataRow}")
      dcf.decodeDCF77()
      echo(fmt"Hour: {dcf.getHour()}:{dcf.getMinute()}")
      echo(fmt"Data: {dcf.getDay()}/{dcf.getMonth()}/{dcf.year+2000}")
      if dcf.isCest == true:
        echo("------ ESTATE -----")
      else:
        echo("------ INVERNO ------")
      stampa = true
    elif dcf.engagedSignal == false and dcf.isReadyDcf77 == false:
      echo("Waiting for a Valid Signal..")
    elif dcf.engagedSignal == true and dcf.isReadyDcf77 == false:
      echo("Signal Found, Awaited Data Reception..")
    if stampa == true:
      dcf.receiveDCF77()
      stampa = false
    sleepMs(500)
