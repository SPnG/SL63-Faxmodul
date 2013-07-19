#!/bin/bash
#
##############################################################################
#
# Ermittlung des X Displays von NXClient Usern zur Nutzung von Xdialog;
#
# Dieses Script schreibt die ermittelte Display Variable in eine Textdatei,
# welche von der SPnG Version der xfax.sh ausgewertet wird.
#
# 4H (TH), Stand: Februar 2013
#
##############################################################################

# los geht's:

if [ -d .nx/C* ];then
   Tkennung=`ls -d .nx/C* | awk -F"-" '{print $3}'`
   Display=:$Tkennung.0
   echo $Display  >$HOME/DisplayAusgabe
else
   # Kein NX Arbeitsplatz
   echo ":0.0"  > $HOME/DisplayAusgabe
fi

chmod 777 $HOME/DisplayAusgabe
export DISPLAY=`cat $HOME/DisplayAusgabe`
export XAUTHORITY=$HOME/.Xauthority

Rueckgabe=`cat $HOME/DisplayAusgabe`
if [ $DISPLAY = $Rueckgabe ]; then
   Xdialog --title "Initialisierung des Faxmoduls" \
           --infobox "$DISPLAY (ok)" 10 60 4000
else
   Xdialog --title "Initialisierung des Faxmoduls" \
           --msgbox "ACHTUNG !!! DisplayAusgabe fehlerhaft gesetzt. \
             Initialisierung des Faxmoduls fehlgeschlagen. $DISPLAY = $Rueckgabe" 0 0
fi

exit 0