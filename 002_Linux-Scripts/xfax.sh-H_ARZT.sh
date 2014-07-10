#!/bin/bash





###############################################################################
#                                                                             #
# Dieses Skript ist Bestandteil des Speedpoint Faxmoduls.                     #
# Zur Konfiguration und zur Bedienung bitte entsprechende Anleitung beachten! #
#                                                                             #
# !! DispplayAusgabe.sh erforderlich, siehe Anleitung !!                      # 
#                                                                             #
#                                                                             #
#                                                                             #
# Speedpoint next Generations GmbH (4H,MR,FW), Stand: Mai 2013                #
#                                                                             #
###############################################################################





###############################################################################
#
# Konfigurationsbereich - Bitte anpassen:                                              
#
cupsout="faxout"                         # Outputordner für cups-pdf in trpword
#
winpc="200.0.0.2"                        # IP Adresse des Windowsrechners
#
port="6666"                              # Rexserver Port am Windows PC
#
linuxpc="200.0.0.1"                      # IP Adresse des DATA VITAL Servers
#
smbshare="Word"                          # Samba Freigabename fuer trpword
#
FriFax="c:\\FritzSendFax\\4hfrifa20.exe" # Windows Pfad der 4hFrifa20.exe
#
debug=false                              # falls 'true', Logdaten erhalten
#
# Ende des Konfigurationsbereiches
#
###############################################################################





# Ab hier bitte Finger weg ----------------------------------------------------




function_cleanlogs()
{
  # Logfiles aufraeumen:
  if [ $debug ]; then
     rm -f $faxfile               2>/dev/null
     rm -f $FaxPfad/*.pdf         2>/dev/null
     rm -f $faxfehler             2>/dev/null
     rm -f $FaxPfad/Faxversand.ok 2>/dev/null
     rm -f $aerztelisteprg        2>/dev/null
  fi
}


# Definitionen:
#
FaxNr=$2
FaxPfad=/home/david/trpword/$cupsout
FaxPfadWin="\\\\$linuxpc"\\$smbshare\\$cupsout\\
ichbins=`whoami`
Xdialog="/usr/bin/Xdialog"
export XAUTHORITY=/home/$ichbins/.Xauthority
export DISPLAY=`cat /home/$ichbins/DisplayAusgabe`


# Fehler ausgeben, falls keine Ausgabedatei von DisplayAusgabe.sh gefunden:
#
if [ ! -e /home/$ichbins/DisplayAusgabe ]; then
   echo ""
   echo "****************************************************************"
   echo "Faxmodul nicht initialisiert, wurde DisplayAusgabe.sh gestartet?"
   echo "****************************************************************"
   echo ""
   exit 1
fi


###############################################################################
# Ermittlung des akt. Users sowie dessen Terminal-ID                          #
#                                                                             #
# Die Terminal-ID sollte in der david.cfg eindeutig sein, ansonsten           #
# wird mit einem Fehler abgebrochen.                                          #
###############################################################################
#
# Terminal-IDs von $ichbins in der david.cfg auffinden:
userid="$(sed -n "/^${ichbins}/p" /home/david/david.cfg | awk '{print $10}')"
zahl="$(expr length "`echo $userid`")"


# Feststellen, ob mehrere Terminal-IDs geliefert wurden:
#
if [[ $zahl -gt 2 ]]; then
   $Xdialog --title "Konfigurationsfehler"                                         \
            --ok-label "Abbruch"                                                   \
            --msgbox "Mehrere DV Terminalkennungen fuer User '$ichbins' gefunden.\n\
                     Kein Faxversand moeglich." 0 0
   function_cleanlogs
   exit 1
elif [[ $2 = $ichbins ]]; then
     quelle="pdf"
     FaxNr=""
fi
#
if [ ! $2 ];then
   quelle=pdf
fi


# Aerzteliste zur Anzeige mit Xdialog vorbereiten:
#
aerzteliste1=/home/david/trpword/aerzte.001
aerztelisteprg=/home/david/aerzteliste.sh
ueberweiser1=/home/david/trpword/$userid/ueberweiser.txt
UFile=/home/david/trpword/$userid/patienten$userid.txt
PFile=/home/david/trpword/$userid/text.$userid


# Sonderzeichen filtern und Umlaute konvertieren:
#
iconv -f ISO-8859-1 -t UTF-8 $UFile > $ueberweiser1
if [ $quelle = "pdf" ];then
   if [ -e $UFile ];then
      #FaxNr=`tail -n1 $ueberweiser1 | awk -F";" '{print $55}' |sed 's/[^0-9]//g'`
      #UArzt=`tail -n1 $ueberweiser1 | awk -F";" '{print $51}'|tr -d "[]"`
      #UOrt=`tail -n1 $ueberweiser1 | awk -F";" '{print $53}' `
      #UStr=`tail -n1 $ueberweiser1 | awk -F";" '{print $52}' `
      # Auf Kundenwunsch den Hausarzt suchen, nicht den U-Arzt: 
      FaxNr=`tail -n1 $ueberweiser1 | awk -F";" '{print $69}' |sed 's/[^0-9]//g'`
      UArzt=`tail -n1 $ueberweiser1 | awk -F";" '{print $65}'|tr -d "[]"`
      UOrt=`tail -n1 $ueberweiser1 | awk -F";" '{print $67}' `
      UStr=`tail -n1 $ueberweiser1 | awk -F";" '{print $66}' `
   fi
fi
rm $ueberweiser1


# Namen des PDF festlegen:
#
if [ -e $PFile ];then
   if [ -e $UFile ];then
      PatNr=$( sed -n '1,1 p' $PFile)
   fi
fi
#
if [ ! $PatNr ];then
   PatNr="Namenlos"
fi


# Ausgeben der Werte in Logdateien:
#
faxfehler=$FaxPfad/Faxerror.txt
echo winpc:$winpc > $faxfehler
echo PatDatenFile:$PFile >> $faxfehler
echo FaxPfad:$FaxPfad >> $faxfehler
echo Faxdatei:$1 >> $faxfehler
echo Faxnr:$2 >> $faxfehler
echo quelle:$quelle >> $faxfehler


# Fehlerbehandlungen:
#
if [[ ! $1 ]]; then
   $Xdialog --msgbox "Es wurde keine Faxdatei uebergeben." 6 60   
   echo "Es wurde keine Datei angegeben." >> $faxfehler
   function_cleanlogs
   exit 1
fi


# Hauptteil - Dialoge zur Eingabe der Faxnummer generieren:
#
if [[ $quelle = pdf ]]; then
   retval=""
   until [ $retval = 0 -o $retval = 255 ]; do      
      # Ermitteln, ob seitens DV eine Exportdatei bereit liegt: 
      if [ -s $UFile ]; then
         zusatz="\n\nAktueller Hausarzt:\n\n$UArzt\n$UStr\n$UOrt"
      else
         zusatz=""
      fi
      #
      $Xdialog --cancel-label "Arzt suchen"  \
               --title "Faxnummer eingeben"  \
               --clear                       \
               --inputbox "- Bitte die Faxnummer eingeben -$zusatz" 20 70 $FaxNr 2>/tmp/inbox.tmp.$$
      retval=$?
      FaxNr=`cat /tmp/inbox.tmp.$$`
      rm -f /tmp/inbox.tmp.$$
      if [[ $retval = 1 ]]; then 
         if [ -e $aerzteliste1 ];then
            # ausführbare Datei mit Xdialog u. integrierter Ärzteliste erzeugen:
            # Leerzeile am Anfang (wegen bash)
            echo -e "\n" >$aerztelisteprg 
            chmod 775 $aerztelisteprg  
            # Teil 1 des Xdialogs in Programmdatei einfügen:
            echo "$Xdialog --cancel-label "\""Zurueck zur manuellen Eingabe"\"" \
                           --title "\""Faxnummer Auswahl"\""                    \
                           --menu "\""Liste der Ueberweiser"\"" 30 90 14 \\" >> $aerztelisteprg
            # Ärzteliste einfügen
            # Teil 2 des Xdialogs in Programmdatei einfügen
            iconv -f ISO-8859-1 -t UTF-8 $aerzteliste1 | awk -v HK="\"" -F";" '{gsub(" ","",$8)}{if($8!="")print HK$4HK" "HK$8HK" \\"}' | sort >>$aerztelisteprg
            echo "2> /tmp/inbox.tmp.$$" >> $aerztelisteprg
            # erstelltes Xdialog-Programm ausführen
            $aerztelisteprg
            # Faxnr herausfiltern
            select=`cat /tmp/inbox.tmp.$$`
            FaxNr=`cat $aerztelisteprg|fgrep -w "$select"|awk '{print $(NF-1)}'|sed 's/[^0-9]//g'`
            rm -f /tmp/inbox.tmp.$$
         else
            $Xdialog --title "Listenanzeige" --msgbox "Es ist keine Ueberweiserdatei vorhanden" 6 60
         fi
      fi
   done
fi


# Leere Faxnummer uebergeben oder Abbruch durch Benutzer:
#
if [[ ! $FaxNr && $retval = 0 ]]; then
   $Xdialog --title "Abbruch" --msgbox "Es wurde keine Faxnummer eingegeben." 6 60
   echo "Es wurde keine Faxnummer angegeben." >> $faxfehler
   function_cleanlogs
   exit 1
elif [[ $retval = 255 ]]; then
   $Xdialog --title "Abbruch" --msgbox "Abbruch durch Benutzer" 6 60
   echo "Abbruch durch Benutzer." >> $faxfehler
   function_cleanlogs
   exit 1
fi


# Keine Datei als Parameter von CUPS erhalten:
#
if [[ ! -e $1 ]]; then
   $Xdialog --msgbox "Faxdatei wurde nicht gefunden." 6 60
   echo "Faxdatei  wurde nicht gefunden." >> $faxfehler
   function_cleanlogs
   exit 1
fi


# ggf. Konvertierung des Dokuments nach PDF:
#
echo "Variablen sind OK" >> $faxfehler
if [ `file $1 | awk -F":" '{print $2}' | head -c4 | tail -c3` = "PDF" ];then
   faxfile=$1
else
   ps2pdf $1 $1.pdf
   faxfile=$1.pdf
fi


# Fax samt Parameter bereitstellen:
#
echo Faxfile:$faxfile >> $faxfehler
echo Ziel:$FaxPfad/$PatNr.pdf >> $faxfehler
echo Faxnummer:$FaxNr >> $faxfehler
cp $faxfile $FaxPfad/$PatNr.pdf
chmod 777 $FaxPfad/*
if [[ ! $FaxPfad/$PatNr.pdf ]]; then
   echo "Exportdatei nicht gefunfden" >> $faxfehler
   rm $FaxPfad/Faxversand.ok
   exit
fi


# Uebergabe der Faxdatei mitsamt Parametern an Windows: 
#
echo "DAVCMD $FriFax" $FaxNr $PatNr.pdf $PatNr $FaxPfadWin | netcat $winpc $port


# Fehlerpruefung von Seiten 4hFriFa20.exe:
#
faxlog=$FaxPfad/Faxprotokoll.txt
status="$(echo "Pat-Nr:"$PatNr "  -  "   \
        $(sed -n '7,7 p' $PFile) "  -  " \
        $(sed -n '8,8 p' $PFile) "  -  " \
        $(sed -n '9,9 p' $PFile) "  -  " \
        $(sed -n '6,6 p' $PFile))"
#
if [ -f $FaxPfad/Faxversand.ok ]; then
   date >>$faxlog
   echo $status >>$faxlog
   echo "Fax Vorbereitung fuer User '$ichbins' an $FaxNr ok." >>$faxlog
   echo "FritzFax Aufruf an $winpc erfolgreich." >>$faxlog
else
   date >>$faxlog
   echo "" >>$faxlog
   echo "######" >>$faxlog
   echo "######  FEHLER  :-(" >>$faxlog
   echo "######  FritzFax Aufruf fuer User '$ichbins' fehlgeschlagen." >>$faxlog
   echo "######  Bitte Laufwerk W: & Konfiguration von 4hFriFa.exe pruefen." >>$faxlog
   echo "######" >>$faxlog
   echo "" >>$faxlog
   echo $status >>$faxlog
   cat $faxfehler >>$faxlog
   
   rm -f $FaxPfad/$PatNr.pdf
   $Xdialog --title "Fehler"                                \
           --center                                        \
           --msgbox "Aufruf des Faxmoduls fehlgeschlagen.\n\
                     Bitte $faxlog pruefen." 0 0
fi
#
function_cleanlogs
echo "---------------------------------------------------------------------" >>$faxlog


# umfasst $faxlog mehr als 2000 Zeilen, werden die aeltesten 20 Zeilen geloescht.
# Erfolge erzeugen je 5, Misserfolge je 20 Eintraege.
if [ `sed -n $= $faxlog` -gt 2000 ]; then sed -i '1,20d' $faxlog; fi


# Konvertierung der Protokolldateien fuer Windows Editoren:
unix2dos $FaxPfad/Fax*.txt


exit 0
