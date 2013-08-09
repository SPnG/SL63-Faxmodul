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

# alte NX-Cacheordner entfernen? (0 oder 1)
rmnxcache="0"


# los geht's:

# =====================================================
# alte NX-Cacheordner entfernen
if [ $rmnxcache = "1" ]; then
   if [ "`find .nx/ -name C-* -type d`" ];then
      neu="`ls -tc .nx | grep '^C-' | sed -n '1p'`"
      for i in `ls .nx | grep '^C-'`; do
         if [ $i != $neu ]; then
            rm -f $i
         fi
      done
   fi
fi
# =====================================================


if [ "`find .nx/ -name C-* -type d`" ];then
   Tkennung="`ls -tc .nx | grep '^C-' | sed -n '1p' | awk -F"-" '{print $3}'`"
   Display=:$Tkennung.0

   echo $Display  >$HOME/DisplayAusgabe
else
   # Xdialog --infobox "Verzeichnis exitiert nicht" 0 0 2000
   echo ":0.0"  > $HOME/DisplayAusgabe
fi

chmod 777 $HOME/DisplayAusgabe
export DISPLAY=`cat $HOME/DisplayAusgabe`
export XAUTHORITY=$HOME/.Xauthority

Rueckgabe=`cat $HOME/DisplayAusgabe`
if [ $DISPLAY = $Rueckgabe ];then
   Xdialog --title "Initialisierung des Faxmoduls" \
           --infobox "$DISPLAY (ok)" 10 60 4000
else
   Xdialog --title "Initialisierung des Faxmoduls" \
           --msgbox "ACHTUNG !!! DisplayAusgabe fehlerhaft gesetzt. \
             Das Faxmodul wird nicht funktionieren $DISPLAY = $Rueckgabe" 0 0
fi

exit 0
