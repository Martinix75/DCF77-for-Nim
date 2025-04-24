import picostdlib
import picostdlib/pico/[stdio, time]
import picostdlib/hardware/[gpio]
import std/[math, strformat]
# simulatore dcf77 
let dcf77SimulatorVer = "0.2.0"

type 
  DCF77Tr = object
    pinOut: Gpio # pin di uscita del dato
    info: seq[byte] = @[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0] #fissi 15 bit a zero il PRimo deve essere 0.
    periode: seq[byte] #bool = false # false= winter, true=summer
    minute: seq[byte] #uint8 = 15 #minuti di default
    hour: seq[byte] #uint8 = 2 #ore di difault
    day: seq[byte] #uint8 = 27 #numero del giorno 1..31
    weekDay: seq[byte] #uint8 = 6 #(abato 06 1..7)
    mounth: seq[byte] #uint8 = 12 #dicembre (1..12)
    year: seq[byte] #uint8 = 75 #per convezione ra 2075 ma ssarebbe 1975 :)) )
    dataArray: seq[byte] #contiene il dato copleto (59 bit).

proc initDcf77t(pin: int): DCF77Tr = 
  let pin_out = pin.Gpio; pin_out.init(); pin_out.setDir(Out); pin_out.pullDown()
  result = DCF77Tr(pinOut: pin_out)

proc parity(self: DCF77Tr; data: seq[uint8]): uint8 =
  result = 0
  for index in data:
    if index == 1:
      result = result xor 1
  
proc decimalToBcd(self: DCF77Tr; number: uint8): seq[uint8] =
  var 
    num = number
    digits: seq[uint8]
  let refill:seq[uint8] = @[0,0,0,0]
  if num == 0:
    result =  @[0,0,0,0,0,0,0,0,0]
  while num > 0:
    digits.add(num mod 10)
    num = num div 10
  if number < 10:
    digits.add(refill) #aggiunge una cifra a zero seno va in chrasc perche manca.
  for posNum in countUp(0, digits.len()-1):
    let digitx = digits[posNum]
    for indexBit in 0..3:
      result.add((digitx shr indexBit) and 1)

proc bTc(self: DCF77Tr; data: seq[uint8]; par=true): uint8 = #ritorna il valore decimale dei dati x visualizzare
  var scale = 1
  if par == true:
    scale = 2
  #echo("---> DATA: ", data)
  let bcdValue = [1.byte,2,4,8,10,20,40,80]
  for index in 0..len(data)-scale:
    result = result + (data[index] * bcdValue[index])
    #echo("BTC: ", result)
  
proc createPeriode(self: DCF77Tr; pe: bool): seq[uint8] = #crea l'array per estivo/inverono 0 iniziale obbigatorio 1 finale obbligatorio.
  if pe == true:
    result = @[0,0,0,1,0,1]  #ritorna orario INVERNALE.
  else:
    result = @[0,0,1,0,0,1] #ritorna orario ESTIVO.

proc createSemiData(self: DCF77Tr; data:uint8; pos:uint; par: bool): seq[uint8] = #calcola il valore bcd ddel dato, mette in sequenza e parità.
  var tempSeq: seq[uint8]
  var parity: uint8
  let bcdMin = self.decimalToBcd(data)
  for j in 0..pos-1:
    tempSeq.add(bcdMin[j])
  if par == true: #se richista parità da specifica.
    parity = self.parity(tempSeq)
    tempSeq.add(parity)
    result = tempSeq
    #echo("Senza Con parita: ",tempSeq)
  else:
    result = tempSeq
    #echo("Con parita: ",tempSeq)


proc getData(self: DCF77Tr; raw=false) = #stampa data e ora sulla seriale.
  let
    min = self.btc(self.minute, true)
    hor = self.btc(self.hour, true)
    day = self.btc(self.day, false)
    mounth = self.btc(self.mounth, false)
    year = self.btc(self.year, false)
  echo(fmt"HOUR: {hor}:{min} DATE: {day}/{mounth}/{1900+year}")
  if raw == true:
    echo(fmt"Data Raw --> {self.dataArray}")
    
proc putData(self: var DCF77Tr; pe=false; mi=15; ho=2;dy=27; wd=6; mo=12; ye=75) =
  self.periode = self.createPeriode(pe)
  self.minute = self.createSemiData(mi.uint8, 7, true)
  self.hour = self.createSemiData(ho.uint8, 6, true)
  #echo("--------- Dammi ora: ", self.hour)
  self.day = self.createSemiData(dy.uint8, 6, false)
  self.weekDay = self.createSemiData(wd.uint8, 3, false)
  self.mounth = self.createSemiData(mo.uint8, 5, false)
  self.year = self.createSemiData(ye.uint8, 8, false)
  let seqData: seq[uint8] = self.day & self.weekDay & self.mounth & self.year #iserisce le sibgole componenti in un unica seq.
  self.dataArray = self.info & self.periode & self. minute & self.hour & seqData
  self.dataArray.add(self.parity(seqData)) #calcola la parita dell'array totale della data.
  
proc sendData(self: var DCF77Tr) = #procedura per sperire i dati al ricevitore.
  for dato in self.dataArray:
    if dato == 1:
      self.pinOut.put(High)
      sleepMs(200)
      self.pinOut.put(Low)
      sleepMs(800)
    elif dato == 0:
      self.pinOut.put(High)
      sleepMs(100)
      self.pinOut.put(Low)
      sleepMs(900)
  sleepMs(1000) #PAUSA OBBLIGATORIA CHE SIMULA IL SILENZIO DEL 59 -->00 SECONDO"

  
when isMainModule:
  stdioInitAll()
  sleepMs(1500)
  var dcf = initDcf77t(2)
  dcf.putData() #cosi mette i dati di default.
  while true:
    dcf.getData(true)
    dcf.sendData()
    sleepMs(700)
