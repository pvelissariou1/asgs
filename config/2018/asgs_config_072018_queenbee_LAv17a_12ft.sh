#!/bin/sh
#-------------------------------------------------------------------
# config.sh: This file is read at the beginning of the execution of the ASGS to
# set up the runs  that follow. It is reread at the beginning of every cycle,
# every time it polls the datasource for a new advisory. This gives the user
# the opportunity to edit this file mid-storm to change config parameters
# (e.g., the name of the queue to submit to, the addresses on the mailing list,
# etc)
#-------------------------------------------------------------------
#
# Copyright(C) 2018 Jason Fleming
#
# This file is part of the ADCIRC Surge Guidance System (ASGS).
#
# The ASGS is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# ASGS is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# the ASGS.  If not, see <http://www.gnu.org/licenses/>.
#-------------------------------------------------------------------

# Fundamental

INSTANCENAME=072018LAv17a_12ft  # "name" of this ASGS process
COLDSTARTDATE=2018081200    # calendar year month day hour YYYYMMDDHH24
HOTORCOLD=hotstart      # "hotstart" or "coldstart"
LASTSUBDIR=/ssdwork/jgflemin/asgs5006/2018090306 # path to previous execution (if HOTORCOLD=hotstart)
HINDCASTLENGTH=20.0      # length of initial hindcast, from cold (days)
REINITIALIZESWAN=no      # used to bounce the wave solution

# Source file paths

ADCIRCDIR=~/adcirc/forks/adcirc/v53release/work # ADCIRC executables
SWANDIR=~/adcirc/forks/adcirc/v53release/swan   # SWAN executables
SCRIPTDIR=~/asgs/branches/2014stable          # ASGS executables
INPUTDIR=${SCRIPTDIR}/input/meshes/LA_v17a # grid and other input files
OUTPUTDIR=${SCRIPTDIR}/output # post processing scripts
PERL5LIB=${SCRIPTDIR}/PERL    # DateCale.pm perl module

# Physical forcing

BACKGROUNDMET=off   # NAM download/forcing
TIDEFAC=on           # tide factor recalc
TROPICALCYCLONE=on   # tropical cyclone forcing
WAVES=off             # wave forcing
VARFLUX=off          # variable river flux forcing

# Computational Resources

TIMESTEPSIZE=1.0           # adcirc time step size (seconds)
SWANDT=1200                 # swan time step size (seconds)
HINDCASTWALLTIME="18:00:00" # hindcast wall clock time
ADCPREPWALLTIME="01:00:00"  # adcprep wall clock time, including partmesh
NOWCASTWALLTIME="07:00:00"  # longest nowcast wall clock time
FORECASTWALLTIME="07:00:00" # forecast wall clock time
NCPU=1160                     # number of compute CPUs for all simulations
NUMWRITERS=20
NCPUCAPACITY=3600
CYCLETIMELIMIT="05:00:00"
#QUEUENAME=workq
#SERQUEUE=single
QUEUENAME=priority
SERQUEUE=priority
if [[ $SERQUEUE = priority ]]; then
   PREPCONTROLSCRIPT=queenbee.adcprep.priority.template.pbs # sets ppn=20
fi
ACCOUNT=loni_cera_2018a
SCRATCHDIR=/ssdwork/$USER    # vs default /work/cera

# External data sources : Tropical cyclones

STORM=07                         # storm number, e.g. 05=ernesto in 2006
YEAR=2018                        # year of the storm
TRIGGER=rssembedded              # either "ftp" or "rss"
RSSSITE=filesystem
FTPSITE=filesystem
FDIR=~/asgs/branches/2014stable/input/sample_advisories/2018
HDIR=${FDIR}
#RSSSITE=www.nhc.noaa.gov         # site information for retrieving advisories
#FTPSITE=ftp.nhc.noaa.gov         # hindcast/nowcast ATCF formatted files
#FDIR=/atcf/afst                  # forecast dir on nhc ftp site
#HDIR=/atcf/btk                   # hindcast dir on nhc ftp site

# External data sources : Background Meteorology

FORECASTCYCLE="06"
BACKSITE=ftp.ncep.noaa.gov          # NAM forecast data from NCEP
BACKDIR=/pub/data/nccf/com/nam/prod # contains the nam.yyyymmdd files
FORECASTLENGTH=84                   # hours of NAM forecast to run (max 84)
PTFILE=ptFile_oneEighth.txt         # the lat/lons for the OWI background met
ALTNAMDIR="/projects/ncfs/data/asgs5463","/projects/ncfs/data/asgs14174"

# External data sources : River Flux

RIVERSITE=ftp.nssl.noaa.gov
RIVERDIR=/projects/ciflow/adcirc_info

# Input files and templates

GRIDFILE=LA_v17a-WithUpperAtch_chk.grd   # mesh (fort.14) file
GRIDNAME=LA_v17a-WithUpperAtch_chk
MESHPROPERTIES=${GRIDFILE}.properties
CONTROLTEMPLATE=LA_v17a-WithUpperAtch_MS12ft.15.template
CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
ELEVSTATIONS=combined_stations_20180611.txt
VELSTATIONS=combined_stations_20180611.txt
METSTATIONS=combined_stations_20180611.txt
NAFILE=LA_v17a-WithUpperAtch.13
NAPROPERTIES=${NAFILE}.properties
SWANTEMPLATE=LA_v17a-WithUpperAtch.26.template   # only used if WAVES=on
RIVERINIT=null                           # this mesh has no rivers ...
RIVERFLUX=null
HINDCASTRIVERFLUX=null
PREPPEDARCHIVE=prepped_${GRIDNAME}_${INSTANCENAME}_${NCPU}.tar.gz
HINDCASTARCHIVE=prepped_${GRIDNAME}_hc_${INSTANCENAME}_${NCPU}.tar.gz

# Output files

# water surface elevation station output
FORT61="--fort61freq 300.0 --fort61netcdf" 
# water current velocity station output
FORT62="--fort62freq 0"                    
# full domain water surface elevation output
FORT63="--fort63freq 3600.0 --fort63netcdf" 
# full domain water current velocity output
FORT64="--fort64freq 3600.0 --fort64netcdf" 
# met station output
FORT7172="--fort7172freq 300.0 --fort7172netcdf"           
# full domain meteorological output
FORT7374="--fort7374freq 3600.0 --fort7374netcdf"           
#SPARSE="--sparse-output"
SPARSE=""
NETCDF4="--netcdf4"
OUTPUTOPTIONS="${SPARSE} ${NETCDF4} ${FORT61} ${FORT62} ${FORT63} ${FORT64} ${FORT7172} ${FORT7374}"
# fulldomain or subdomain hotstart files
HOTSTARTCOMP=fulldomain                    
# binary or netcdf hotstart files
HOTSTARTFORMAT=netcdf                      
# "continuous" or "reset" for maxele.63 etc files
MINMAX=reset                               

# Notification

EMAILNOTIFY=yes         # yes to have host HPC platform email notifications
NOTIFY_SCRIPT=corps_cyclone_notify.sh
ACTIVATE_LIST=null
NEW_ADVISORY_LIST=null
POST_INIT_LIST=null
POST_LIST=null
JOB_FAILED_LIST="jason.g.fleming@gmail.com"
NOTIFYUSER=jason.g.fleming@gmail.com
ASGSADMIN=jason.g.fleming@gmail.com

# Post processing and publication

INTENDEDAUDIENCE=general
INITPOST=null_init_post.sh
POSTPROCESS=queenbee_daily_post.sh
POSTPROCESS2=null_post.sh

# opendap
TDS=(renci_tds)
TARGET=queenbee  # used in post processing to pick up HPC platform config
# You must first have your ssh public key in ~/.ssh/authorized_keys2 file 
# on the opendap server machine in order to scp files there via
# opendap_post.sh. OPENDAPHOST is set to each value in the TDS array specified
# above and used by your post processing script to successively trigger 
# configuration via platforms.sh. The OPENDAPUSER parameter needs to be set
# here, rather than in platforms.sh or your post processing script,
# because multiple Operators may be posting to a particular opendap server
# using different usernames. 
OPENDAPUSER=ncfs         # default value that works for RENCI opendap 
if [[ $OPENDAPHOST = "fortytwo.cct.lsu.edu" ]]; then
   OPENDAPUSER=jgflemin  # change this for other Operator running on queenbee
fi
# OPENDAPNOTIFY is used by opendap_post.sh and could be regrouped with the 
# other notification parameters above. 
OPENDAPNOTIFY="asgs.cera.lsu@gmail.com,jason.g.fleming@gmail.com"

NUMCERASERVERS=2
WEBHOST=webserver.hostingco.com
WEBUSER=remoteuser
WEBPATH=/home/remoteuser/public_html/ASGS/outputproducts

# Archiving

ARCHIVE=enstorm_pedir_removal.sh
ARCHIVEBASE=/ssdwork/jgflemin
ARCHIVEDIR=${ARCHIVEBASE}/asgs_archive

# Forecast ensemble members

RMAX=default
PERCENT=default
ENSEMBLESIZE=4 # number of storms in the ensemble
case $si in
-1)
      # do nothing ... this is not a forecast
   ;;
1)
   ENSTORM=nhcConsensus
   ;;
0)
   ENSTORM=nhcConsensusWind10m
   ADCPREPWALLTIME="00:20:00"  # adcprep wall clock time, including partmesh
   FORECASTWALLTIME="00:20:00" # forecast wall clock time
   CONTROLTEMPLATE=LA_v17a-WithUpperAtch.nowindreduction.15.template
   CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
   TIMESTEPSIZE=60.0    # 15 minute time steps
   NCPU=19               # dramatically reduced resource requirements
   NUMWRITERS=1          # multiple writer procs might collide
   WAVES=off             # deactivate wave forcing 
   # turn off water surface elevation station output
   FORT61="--fort61freq 0"
   # turn off water current velocity station output
   FORT62="--fort62freq 0"
   # turn off full domain water surface elevation output
   FORT63="--fort63freq 0"
   # turn off full domain water current velocity output
   FORT64="--fort64freq 0"
   # met station output
   FORT7172="--fort7172freq 300.0 --fort7172netcdf"
   # full domain meteorological output
   FORT7374="--fort7374freq 3600.0 --fort7374netcdf"
   #SPARSE="--sparse-output"
   SPARSE=""
   NETCDF4="--netcdf4"
   OUTPUTOPTIONS="${SPARSE} ${NETCDF4} ${FORT61} ${FORT62} ${FORT63} ${FORT64} ${FORT7172} ${FORT7374}"
   # prevent collisions in prepped archives
   PREPPEDARCHIVE=prepped_${GRIDNAME}_${INSTANCENAME}_${NCPU}.tar.gz
   POSTPROCESS=null_post.sh
   ;;
3)
   ENSTORM=veerLeft100
   PERCENT=-100
   ;;
2)
   ENSTORM=veerLeft100Wind10m
   PERCENT=-100
   ADCPREPWALLTIME="00:20:00"  # adcprep wall clock time, including partmesh
   FORECASTWALLTIME="00:20:00" # forecast wall clock time
   CONTROLTEMPLATE=LA_v17a-WithUpperAtch.nowindreduction.15.template
   CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
   TIMESTEPSIZE=60.0    # 15 minute time steps
   NCPU=19               # dramatically reduced resource requirements
   NUMWRITERS=1          # multiple writer procs might collide
   WAVES=off             # deactivate wave forcing 
   # turn off water surface elevation station output
   FORT61="--fort61freq 0"
   # turn off water current velocity station output
   FORT62="--fort62freq 0"
   # turn off full domain water surface elevation output
   FORT63="--fort63freq 0"
   # turn off full domain water current velocity output
   FORT64="--fort64freq 0"
   # met station output
   FORT7172="--fort7172freq 300.0 --fort7172netcdf"
   # full domain meteorological output
   FORT7374="--fort7374freq 3600.0 --fort7374netcdf"
   #SPARSE="--sparse-output"
   SPARSE=""
   NETCDF4="--netcdf4"
   OUTPUTOPTIONS="${SPARSE} ${NETCDF4} ${FORT61} ${FORT62} ${FORT63} ${FORT64} ${FORT7172} ${FORT7374}"
   # prevent collisions in prepped archives
   PREPPEDARCHIVE=prepped_${GRIDNAME}_${INSTANCENAME}_${NCPU}.tar.gz
   POSTPROCESS=null_post.sh
   ;;
4)
   ENSTORM=veerRight100
   PERCENT=100
   ;;
5)
   ENSTORM=veerRight100Wind10m
   PERCENT=100
   ADCPREPWALLTIME="00:20:00"  # adcprep wall clock time, including partmesh
   FORECASTWALLTIME="00:20:00" # forecast wall clock time
   CONTROLTEMPLATE=LA_v17a-WithUpperAtch.nowindreduction.15.template
   CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
   TIMESTEPSIZE=60.0    # 15 minute time steps
   NCPU=19               # dramatically reduced resource requirements
   NUMWRITERS=1          # multiple writer procs might collide
   WAVES=off             # deactivate wave forcing 
   # turn off water surface elevation station output
   FORT61="--fort61freq 0"
   # turn off water current velocity station output
   FORT62="--fort62freq 0"
   # turn off full domain water surface elevation output
   FORT63="--fort63freq 0"
   # turn off full domain water current velocity output
   FORT64="--fort64freq 0"
   # met station output
   FORT7172="--fort7172freq 300.0 --fort7172netcdf"
   # full domain meteorological output
   FORT7374="--fort7374freq 3600.0 --fort7374netcdf"
   #SPARSE="--sparse-output"
   SPARSE=""
   NETCDF4="--netcdf4"
   OUTPUTOPTIONS="${SPARSE} ${NETCDF4} ${FORT61} ${FORT62} ${FORT63} ${FORT64} ${FORT7172} ${FORT7374}"
   # prevent collisions in prepped archives
   PREPPEDARCHIVE=prepped_${GRIDNAME}_${INSTANCENAME}_${NCPU}.tar.gz
   POSTPROCESS=null_post.sh
   ;;
*)
   echo "CONFIGRATION ERROR: Unknown ensemble member number: '$si'."
   ;;
esac
