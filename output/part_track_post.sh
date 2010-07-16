#!/bin/bash
#
# Copyright(C) 2008, 2009 Jason Fleming
#
# This file is part of the ADCIRC Surge Guidance System (ASGS).
#
# The ASGS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ASGS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with the ASGS.  If not, see <http://www.gnu.org/licenses/>.
#
   CONFIG=$1
   ADVISDIR=$2
   STORM=$3
   YEAR=$4
   ADVISORY=$5
   HOSTNAME=$6
   ENSTORM=$7
   CSDATE=$8
   HSTIME=$9
   GRIDFILE=${10}
   OUTPUTDIR=${11}
   SYSLOG=${12}
  
   #
   . ${CONFIG} # grab all static config info
   #

   # switch to tracking directory
   initialDirectory=`pwd`;
   mkdir ${ADVISDIR}/${ENSTORM}/PartTrack
   # mv *.txt *.csv ${ADVISDIR}/$ENSTORM/tracking
   cd ${ADVISDIR}/$ENSTORM/PartTrack

   PARTICLEFILE=$(ls -tr1 /corral/hurricane/mthoward/*composite*.txt | tail -1  | awk '{print $1}')

   GSHOME2=/usr/bin/
#   GSHOME2=/share/home/01053/rweaver/ghostscript-8.71/bin/
   GMTHOME2=/work/01053/rweaver/GMT4.5.0/bin/

  
#  Create config file for particle tracking and visualizations
 echo "#!/bin/bash              "  > ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
if [ $TROPICALCYCLONE == "off" ];then
  STORM=${ADVISORY}
  KIND=NAM
  WINDVECT=50
  VECTORLIM=30
  VECTCUT=2
  CONTOURLIMmax=2
else
  STORM=$STORM
  KIND=TC
  WINDVECT=120
  VECTORLIM=50
  VECTCUT=5
  CONTOURLIMmax=3.5
fi
 echo "STORM=${STORM}           " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "STORMNAME=${STORM}       " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "CSDATE=${CSDATE}0000         " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "OUTPUTDIR=${OUTPUTDIR}   " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "INPUTDATADIR=${ADVISDIR}/${ENSTORM}               " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
    TRACKDIR=${OUTPUTDIR}/TRACKING_FILES
 echo "TRACKDIR=${TRACKDIR}           " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "ADVISORY=${ADVISORY}           " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "KIND=${KIND}                   " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "PARTICLEFILE=${PARTICLEFILE}   " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "PARTFILETYPE=0   " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "NORTH=31.0       " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "SOUTH=26.0       " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "EAST=-85.0       " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "WEST=-94.2       " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "SYSLOG=${SYSLOG}          " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "NOTIFYUSER=${NOTIFYUSER}  " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "ACCOUNT=${ACCOUNTpost}    " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "GSHOME2=${GSHOME2}        " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "GMTHOME2=${GMTHOME2}      " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "VECTORLIM=$VECTORLIM      " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "CONTOURLIM=-1,$CONTOURLIMmax    " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "WINDVECT=$WINDVECT              " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "VECTCUT=$VECTCUT                " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "PT_POST_LIST=\"$PT_POST_LIST\"      " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "ENSTORM=$ENSTORM                " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf
 echo "HOSTNAME=$HOSTNAME              " >> ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf

     
      ln -fs $TRACKDIR/part_track_main.sh ./part_track_main.sh

       ./part_track_main.sh ${ADVISDIR}/${ENSTORM}/PartTrack/PartTrack_config.conf > PT_main.log 
    
      
  
 
   cd $initialDirectory
