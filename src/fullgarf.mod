#!/bin/sh
#
#  Copyright (C) 2007-2011,2013,2018,2019
#       Smithsonian Astrophysical Observatory
#
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
#
# fullgarf
#
# A list of threads is available at:
#   https://cxc.harvard.edu/ciao/threads/
#
# This script requires its parameter file (fullgarf.par) be available
# to the parameter system.
#
# version string is a.b.c, where a.b is the CIAO release, and c
# the version of the script
#
# Changes:
#   (4.11.1)     Replace check for ASCDS_BIN with ASCDS_INSTALL
#   (4.11)       Add parameter to set ARDLIB qualifyers
#   (4.5)        Support HRC-I
#   (4.1.4)      If bad pixel file is not supplied, use the one from the CALDB
#   (4.1.3)      Replaced use of tail command with CIAO "dmkeypar" tool
#   (4.1.2)      Updated tail syntax to include "-n"
#   (4.1.1)      Provide obsfile reference to evtfile for mkgarf
#   (4.1.0)      Changed dafile and pbkfile defaults for CIAO4,
#   (4.0.1)      Minor fix to grep command
#   (4.0.0)      Add params for dead area, osip file, mask.
#   (for v3.3.1) Moved asphist GTI filter spec from asol to evt
#   (for v2.2.3) Fixed bug that prevented overwriting existing output ARF
#                even with clobber set to 'yes'
#   (for v2.2.2) Renamed from "fullgarf.sh" to "fullgarf".
#   (for v2.2.1) Rewritten, to include the "parameter-file" structure.
#
#
version_str="4.11.1"
version_date="20 September 2019"
#
# Usage:
#   domsg $value $message_string
#
# echo the supplied text to STDOUT IF the global variable
# $verbose is > $value
#
# Example:
#   domsg "Extract background spectrum $bg from $bgevents"
#   domsg Extract background spectrum $bg from $bgevents
#

domsg() {
    vval=$1
    shift
    msg=$@
    if [ $verbose -gt $vval ]; then
	echo "$msg"
    fi
}

filepath()
{
    if [ "$TMPDIR" = "NONE" ]; then
	echo "$1"
	return 0
    fi

    if [ "$TMPDIR" = "" ]; then
	echo "$1"
	return 0
    fi

    fc=`echo $1 | cut -c1`
    if [ "$fc" = "/" ]; then
	echo "$1"
    else
	echo "$TMPDIR/$1"
    fi
}

checkKey ()
{

## Usage: checkKey $keytofind $fitsfile

   if [ "`pquery dmkeypar exist`" = "no" ]; then
      echo "   "
      echo "$1 keyword not found in $2 "
      echo "Aborting. "
      echo "   "
      exit 1
   fi

}

####################################################################
# This routine grabs the value of a specified keyword
# from the header of an input .fits/.qpoe file.
#
# Usage: getKey filename keywordname
# The "returned" value is held in KeyValue
#
# If there is an error (eg. file/keyword doesn't exist)
# the function exits from the script. The variable
# hold serves the purpose of "holding" the screen output
# of dmkeypar. We are not interested in this output.
# Instead, we'll use >> pget dmkeypar ...  to get
# the parameter value. (See >> ahelp dmkeypar ...)
####################################################################

getKey ()
{

   if [ $# -lt 2 ]; then
     echo "   "
     echo "  getKey() Error: No file and/or keyword given  "
     echo "   "
     echo "  USAGE: getKey() fits-file header-keyword "
     echo "   "
     echo "   "
     exit 1
   fi

   hold=`dmkeypar infile=$1 keyword=$2`

#  if   [ $? -ne 0 ] ; then
   if   [ `pquery dmkeypar exist` = "no" ] ; then
     echo "    "
     echo "dmkeypar failure: Keyword $2 not found in file $1 "
     echo "Exiting $0 . . . "
     echo "    "
     exit 1
   fi

   KeyValue=`pget dmkeypar value`
   if   [ $? -ne 0 ] ; then
     echo "    "
     echo "Exiting $0 . . . "
     echo "    "
     exit 1
   fi
}

#####################################################################
# This routine determines whether we are dealing with a Type I or a #
# Type II pha file. It does this by looking at the TFORMx value for #
# the COUNTS column. If the file is a Type I pha file, this keyword #
# should have a value that looks something like "1I" or "1J" ie.    #
# "1" followed by a letter, indicating the data-type. For Type II   #
# files, the value will be something like "8192I" or "8192J", etc.  #
#####################################################################
getPhaPars ()
{
   col_num=`dmlist $phafile"[SPECTRUM]" opt=cols,raw | grep -w COUNTS | awk '{print $2}' | sed -e 's/ //g'`

   if [ "$col_num" = "" ]; then
     echo "   "
     echo "ERROR in getPhaType(): Could not get a column "
     echo "number for column named \"COUNTS\" in $1 "
     echo "  "
     exit 1
   fi

####################################################################
## ASSUMPTION: The line containing the TFORMx keyword is _always_ ##
## displayed as  <something> TFORMx = ?I  <something>  where "?"  ##
## is, of course, the dimensionality of the column. It is assumed ##
## that the  TFORMx = value  is present.                          ##
####################################################################
   tform=`dmlist $phafile opt=header,raw | sed -n "/TFORM${col_num} /p" | sed -e  's/^.*TFORM[1-9][0-9]* *= *\([1-9][0-9]*\).*/\1/'`

   if [ "$tform" = "" ]; then
     echo "   "
     echo "  ERROR in getPhaPars(): Could not get TFORMx for \"COUNTS\" "
     echo "   "
     exit 1
   fi

################################################################
## Get needed pars. from the pha file: Type II file --> Data  ##
## in fits table, Type I file --> Data is in header keywords. ##
################################################################
   if [ "$tform" = "1" ]; then
      tmp=`dmkeypar $phafile TG_PART`
      checkKey TG_PART $phafile
### The TG_PART keyword has a value of 1, 2 or 3. We want HEG/MEG/LEG
      garm=`pquery dmkeypar value | sed -e 's/1/HEG/' -e 's/2/MEG/' -e 's/3/LEG/'`

      tmp=`dmkeypar $phafile TG_M`
      checkKey TG_M $phafile
      ord=`pquery dmkeypar value`

      tmp=`dmkeypar $phafile X`
      checkKey X $phafile
      srcx=`pquery dmkeypar value`

      tmp=`dmkeypar $phafile Y`
      checkKey Y $phafile
      srcy=`pquery dmkeypar value`
   else

########################################################################
## Test to see if the given value for row is valid
########################################################################

      nrows=`dmlist ${phafile}"[SPECTRUM]" counts`

      if [ $prow -gt $nrows ]; then
        echo "    "
        echo "ERROR: Illegal value for pharow "
        echo "$phafile contains $nrows rows, pharow=$prow "
        echo "    "
        exit 1
      fi

      garm=`dmlist ${phafile}"[SPECTRUM][cols tg_part]" opt=raw,data rows=${prow}:${prow} | sed -e '/#/d' -e 's/1/HEG/' -e 's/2/MEG/' -e 's/3/LEG/' -e 's/ //g' `
      ord=`dmlist ${phafile}"[SPECTRUM][cols tg_m]" opt=raw,data rows=${prow}:${prow} | sed -e '/#/d' -e 's/ //g' `

      dmkeypar "${phafile}[SPECTRUM][#row=${prow}]" x echo- > /dev/null 2>&1
      srcx=`pget dmkeypar value`
      dmkeypar "${phafile}[SPECTRUM][#row=${prow}]" y echo- > /dev/null 2>&1
      srcy=`pget dmkeypar value`


   fi

   echo "Grating arm is $garm, order=$ord  "
   echo "Source location is X=${srcx}, Y=${srcy} "
   echo "  "
}

#####################################################################
# These next 2 routines -- getautopars() and getparams() -- get the #
# from the command line / prompt from the pfile and then set the    #
# values in the fullgarf.par file.                                  #
#####################################################################

getautopars()
{
    counter=0
    pfile=`paccess $prog`

    param_list=`sed '/^#/d' $pfile | cut -d, -f1 `
    acclist=`sed '/^#/d' $pfile | cut -d, -f3 `

    hidden_param_list=""
    auto_param_list=""
    nauto=0
    nc=1
    # count auto params
    # The acclist is a a a a h h
    # Advance by 2 chars each time
    #
    for param in $param_list
    do
	atmp=`echo $acclist | cut -c$nc`
	if [ "$atmp" = "a" ]; then
	    nauto=`expr $nauto + 1`
	    auto_param_list=`echo $auto_param_list $param`
	else
	    hidden_param_list=`echo $hidden_param_list $param`
	fi
	nc=`expr $nc + 2`
    done

} # getautpars()

getparams()
{
    enteredParamList=""
    getautopars

    while [ $# -gt 0 ]; do
	#--- count the parameters in the command line
	counter=`expr $counter + 1`

	with_param=`echo $1 | grep '\[.*='`
	if [ "$with_param" = "$1" ]; then
	    # a parameter with DM filter present
	    with_params=`echo $1 | grep '=.*\['`

	    if [ "$with_params" = "$1" ]; then
		# param name was specified
		param=`echo $1 | awk -F= '{print $1}'`
		value=`echo $1 | cut -f2- -d'='`
	    else
		# param name not specified
		param=`echo $auto_param_list | cut -f$counter -d' '`
		value="$1"
	    fi

	else
	    # no DM filter present
	    with_params=`echo $1 | grep =`

	    if [ "$with_params" = "$1" ]; then
		# param name was specified
		param=`echo $1 | awk -F= '{print $1}'`
		value=`echo $1 | cut -f2- -d'='`

	    else
		# param name not specified
		param=`echo $auto_param_list | cut -f$counter -d' '`
		value="$1"
	    fi
	fi

	# if the param is not automatic, counter=(counter - 1)
	# UNLESS the user hasn't supplied a parameter name, which
	# is an error
	if [ "$param" = "" ]; then
	    echo "Problem opening parameter file: too many positional arguments"
	    exit
	fi

	is_auto_par=`echo $auto_param_list | grep $param`
	if [ "$is_auto_par" = "" ]; then
	    #not an auto parameter
	    counter=`expr $counter - 1`
	else
	    # take out the name of the param from entered_param_list
	    for test_param in $param_list
	    do
		if [ "$test_param" = "$param" ]; then
		    entered_param_list=`echo $entered_param_list $test_param`
		fi
	    done
	fi

	#  echo pset $prog ${param}="${value}"
	pset $prog ${param}="${value}"

	# The multi-value parameters which are read in as quoted strings must
	# have their values re-quoted before feeding them to pset()
	shift

    done

} # getparams()

check_writeable()
{
    TMPDIR=.
    dummy=`(echo WTEST > .acheck.tst) 2>/dev/null`
    if [ -f .acheck.tst ]; then
	rm -f .acheck.tst
    else
	echo "No write permission to current directory: using /tmp"
	TMPDIR=/tmp
    fi
}

########

runAsphist ()
{
## When running asphist, either ccd_id (for ACIS) or
## chip_id (HRC) must be specified. The first argument
## to runAsphist() contains the appopriate value.

### We must first get some pars. from parameter file
    clobber=`pquery $pacc clobber`

    if [ "$clobber" = "no" ]; then
      clob=0
    else
      clob=1
    fi

    dtf=`pquery $pacc dtffile`
    asol=`pquery $pacc asol`
    evt=`pquery $pacc evtfile`

    MODE="hl"

### The syntax of asphist depends on the instrument. For
### ACIS, the program looks for a column name "CCD_ID"
### while for HRC it looks for "CHIP_ID". The appropriate
### value is fed into this routine and stored in $chiptag

    chiptag=$1
    shift
    for chip in $@
    do
     if [ "$bpix" = "NONE" ]; then
	# if bad pixel not supplied, use the CALDB bad pixel file
        pset ardlib AXAF_ACIS${chip}_BADPIX_FILE=CALDB
     else
        pset ardlib AXAF_ACIS${chip}_BADPIX_FILE=${bpix}"[BADPIX${chip}]"
     fi
     echo "   "
     if [ ! -f ${root}_ah$chip.fits  -a ! -f ${root}_ah$chip.fits.gz ]; then
        echo asphist infile=$asol  \
                outfile=${root}_ah$chip.fits \
                evtfile=$evt"[$chiptag=$chip]" dtffile=$dtf mode=$MODE

        asphist infile=$asol  \
                outfile=${root}_ah$chip.fits \
                evtfile=$evt"[$chiptag=$chip]" dtffile=$dtf mode=$MODE

        if [ $? -ne 0 ]; then
          echo "   "
          echo "$0: Aborting. "
          echo "   "
          exit 1
        fi

     else
        if [ $clob -eq 1 ]; then
          echo "${root}_ah$chip.fits exists . . . will clobber "
          echo asphist infile=$asol  \
                outfile=${root}_ah$chip.fits \
                evtfile=$evt"[$chiptag=$chip]" dtffile=$dtf clobber=$clobber\
	        mode=$MODE
          asphist infile=$asol \
                outfile=${root}_ah$chip.fits \
                evtfile=$evt"[$chiptag=$chip]" dtffile=$dtf clobber=$clobber\
	        mode=$MODE
        else
          echo " "
          echo "${root}_ah$chip.fits.gz already "
          echo "exists. Cannot clobber . . . skipping"
        fi
     fi
    done
}

########

runMkgarf ()
{
   det=$1

###
## Get some parameters
###
   phafile=`pquery $pacc phafile`
   prow=`pquery $pacc pharow`
   grid=`pquery $pacc engrid`

   #pbk=`pquery $pacc pbkfile`
   da=`pquery $pacc dafile`
   osip=`pquery $pacc osipfile`
   mask=`pquery $pacc maskfile`
   evtfile=`pquery $pacc evtfile`
   ardlibqual=`pquery $pacc ardlibqual`

### We're now ready to run mkgarf . . .
#
   for idet in $detlist
   do
     thischipid=`expr $idet + $add_to_det`
     out=${root}_S${idet}_${garm}_${ord}.fits
     asp=${root}_ah${thischipid}

     mydet="${det}$idet"
     if [ x"$mydet" = x"HRC-I0" ]; then
       mydet=HRC-I
     fi

     if [ ! -f ${out} -a ! -f ${out}.gz ]; then

       echo mkgarf detsubsys=$mydet$ardlibqual \
                   order=$ord \
                   grating_arm=$garm \
		   outfile=$out \
                   asphistfile=${asp}.fits"[ASPHIST]" \
	           obsfile=$evtfile \
                   engrid=${grid} \
		   osipfile=$osip \
		   dafile=$da \
		   pbkfile="" \
		   maskfile=$mask \
	           mirror="HRMA" \
	           sourcepixelx=$srcx \
                   sourcepixely=$srcy \
		   mode="hl" \
		   verb=0

       mkgarf detsubsys="$mydet$ardlibqual" \
                   order=$ord \
		   grating_arm="$garm" \
                   outfile="$out" \
		   asphistfile="${asp}.fits[ASPHIST]" \
	           obsfile=$evtfile \
                   engrid="${grid}" \
		   osipfile=$osip \
		   dafile=$da \
		   pbkfile="" \
		   maskfile=$mask \
	           mirror="HRMA" \
	           sourcepixelx=$srcx \
                   sourcepixely=$srcy \
		   mode="hl" \
		   verb=0

     else

        if [ $clob -eq 1 ]; then
          echo "$out exists . . . will clobber "

          echo mkgarf detsubsys=$mydet$ardlibqual \
	           order=$ord \
                   grating_arm=$garm \
		   outfile=$out \
                   asphistfile=${asp}.fits"[ASPHIST]" \
	           obsfile=$evtfile \
                   engrid=${grid} \
		   osipfile=$osip \
		   dafile=$da \
		   pbkfile="" \
		   maskfile=$mask \
	           mirror="HRMA" \
	           sourcepixelx=$srcx \
                   sourcepixely=$srcy \
		   mode="hl" \
		   verb=0 \
		   clobber=$clobber

          mkgarf detsubsys="$mydet$ardlibqual" \
	           order=$ord \
		   grating_arm="$garm" \
                   outfile="$out" \
		   asphistfile="${asp}.fits[ASPHIST]" \
	           obsfile=$evtfile \
                   engrid="${grid}" \
		   osipfile=$osip \
		   dafile=$da \
		   pbkfile="" \
		   maskfile=$mask \
	           mirror="HRMA" \
	           sourcepixelx=$srcx \
                   sourcepixely=$srcy \
		   mode="hl" \
		   verb=0 \
                   clobber=$clobber
        else
          echo "File ${out}.gz already exists. "
          echo "Cannot clobber. . . skipping."
        fi

     fi

    echo "   "
   done
}

### This routine makes use of previously set variables,
### viz. $garm, $root, $ord

runDmarfadd ()
{
   grat=$garm
   holdfile=$(mktemp -p .)

   type=${grat}_${ord}_garf.fits
   ls -1 ${root}*${grat}_${ord}.fits >> $holdfile
   if [ `wc -l $holdfile | awk '{print $1}'` = 0 ]; then
     rm $holdfile
     echo "  "
     echo "runDmarfadd() ERROR: Could not find grating arfs to concatenate! "
     echo "  "
     exit 1
   fi

   echo dmarfadd @${holdfile}  ${root}${type}

   if [ ! -f ${root}${type} ]; then
     dmarfadd @${holdfile}  ${root}${type}
   else
     if [ $clob -eq 1 ]; then
       echo "${root}${type} already exists . . . will clobber "
       dmarfadd @${holdfile}  ${root}${type} clobber=yes
     else
       echo "${root}${type} already exists . . . cannot clobber! "
     fi
   fi

   rm $holdfile
}

########################################
## This is the "driver" (or, main() ) ##
########################################

#########################################################
### Let's see if the the CIAO tools are available     ###
### ie. if the system has been set up. The idea is    ###
### to check to see if the $ASCDS_INSTALL environment ###
### var. has been set. (The choice of $ASCDS_INSTALL  ###
### is arbitrary.) The test below checks to see if    ###
### "$ASCDS_INSTALL" has a length of 0. Obviously, it ###
### is not set, if this is the case.                  ###
#########################################################
if [ -z "$ASCDS_INSTALL" ]; then
 echo "   "
 echo "It appears as though the CIAO tools have not been setup."
 echo "(I cannot find the environment variable \$ASCDS_INSTALL.) "
 echo "You'll need to set them up in order to run this tool. "
 echo "  "
 exit
fi

######################################################################
## This portion of the code is designed to handle the case where a  ##
## particular parameter file name is given on the command line.     ##
## For example, > readpars.sh  @@file.par.                          ##
######################################################################

prog=`basename $0 | sed -e 's/\.sh//'`
pacc=""

if [ $# -gt 0 ]; then
  if [ `echo $1 | sed 's/^\(..\).*$/\1/'` = "@@" ]; then
      echo "  "
      echo "Sorry, but the @@ syntax is not "
      echo "currently supported for this tool. "
      echo "  "
      exit 1
#     pacc=`echo $1 | sed 's/@//g'`
#     shift
  else
     pacc=`paccess $prog`
  fi
else
  pacc=`paccess $prog`
fi


##################################################
# Get the fullgarf parameters. The top half of   #
# the if block will retrieve all parameters from #
# the command line and store them in shell vars. #
# while the lower block (the else block) will    #
# store the parameters in the Smgarf.par file.   #
# In other words, for the 2nd case the par. vals #
# will need to be read back from the fullgarf.par#
# file before they can be used.                  #
##################################################

#if [ ! -f $pacc ]; then
if [ "$pacc" = "" ]; then
    # Unable to find the parameter file, so we have to read ALL parameters
    # from the command line

    echo "  "
    echo "Could not find the parameter file! "
    echo "(Looked for $pacc)"
    echo "Aborting. "
    echo "  "
    exit 1

############################################################################
## I have not had time to test the script for this scenario (no parameter ##
## file, user inputs all pars on the command line. So the "exit 1" line   ##
## above kicks the user out before it ever gets to this code.             ##
############################################################################
    if [ $# -lt 10 ]; then
        echo "Enter parameters on the command-line or place $pacc "
        echo "into your parameter file path."
        echo "   "
	echo "Syntax: $prog phafile pharow evtfile asol engrid dtffile badpix rootname clobber verbose"
	exit
    fi

   echo ". . . will use command-line parameters "
   echo "   "

   phafile=$1
   pharow=$2
   evtfile=$3
   asol=$4
   engrid=$5
   dtffile=$6
   badpix=$7
   root=$8
   clobber=$9
   verbose=$10

else

    if [ ! -f $pacc ]; then
      echo "   "
      echo "Cannot find the \"$pacc\" paramater file. "
      echo "   "
      echo "   "
      exit 1
    fi

    echo "Will use $pacc for the parameter file."
    # parse the command line for parameters
    totparms=`sed -e "/^#/d" $pacc | wc -l | sed -e 's/ //g' `
    echo "   "
    echo  "$pacc contains $totparms parameters . . . "
    echo "   "
    getparams "$@"
    i=1
    for param in $param_list
    do
	entered=`echo $entered_param_list | grep $param`
	if test "$entered" = ""
	then
#           tparam=`pquery $prog $param`
	    tparam=`pquery $pacc $param`
	else
#           tparam=`pget $prog $param`
	    tparam=`pget $pacc $param`
	fi
    done
fi

################################################################
## The following line is a "hack" :                           ##
## pquery is used often in this script. If the user has set   ##
## mode="ql" in the parameter file, the user will be prompted ##
## for each active parameter, as desired. However, each time  ##
## that pquery is called in this script, the user will again  ##
## be queried for the parameter values! So we do this trick.  ##
################################################################
mode_orig=`pquery $pacc mode`
## | sed -e 's/ //g'`
pset $pacc mode="hl"

############ End, paramater interface ############

root=`pquery $pacc rootname`

phafile=`pquery $pacc phafile`
prow=`pquery $pacc pharow`

if [ ! -f $phafile ]; then
 echo "   "
 echo "ERROR: Cannot find file $phafile "
 echo "Exiting . . . "
 echo "  "
 exit 1
fi

echo "Getting the pha file type . . ."
getPhaPars


###
## getKey() will get the header keyword value
## from the specified fitsfile. The value is
## stored in the shell variable $KeyValue
###
getKey $phafile DETNAM
detnam=`echo $KeyValue | sed -e 's/ //g'`

if [ "$detnam" = "" ]; then
 echo "   "
 echo "ERROR: DETNAM keyword has a null/blank value. "
 echo "Exiting . . ."
 echo "   "
 exit 1
fi

####
## We need to find out what detector was
## used. This line will return a value of
## HRC or ACI (or something else -- if there's
## an error in the input file). The value
## is then tested below to see if it is HRC/ACIS
####
det_test=`echo $detnam | sed 's/\(...\).*/\1/'`

if [ "$det_test" = "HRC" ]; then
  echo "Detector is HRC "

  chip_name=chip_id

######
#### We only need to run asphist/mkgarf for some of the
#### chips/ccds -- those corresponding to positive or
#### negative orders. The chips for which asphist/mkgarf
#### will be run are determined by the detlist variable
######
  add_to_det=0

  if [ $detnam = HRC-S ]; then
    if [ $ord -lt 0 ]; then
      detlist=`echo 2 3`
    else
      detlist=`echo 1 2`
    fi
    detsubsys=HRC-S

  else
    detlist=0
    detsubsys=HRC-I
  fi

  chiplist=$detlist

else
  echo "Detector is ACIS "

  # large y offsets may mean ZO not on acis-7, typically
  # on acis-6.  Need to make arfs for other chips/orders.
  chip_name=ccd_id

  add_to_det=4
  if [ $ord -lt 0 ]; then
    detlist=`echo 0 1 2 3 4`
    chiplist=`echo 4 5 6 7 8`
  else
    detlist=`echo 2 3 4 5`
    chiplist=`echo 6 7 8 9`
  fi

  bpix=`pquery $pacc badpix`
  detsubsys=ACIS-S

fi


echo "Will run asphist for ${chip_name}= $chiplist "
echo "  "

runAsphist $chip_name $chiplist

echo "   "
echo "Finished processing aspect histograms for ${chip_name}= ${chiplist} "
echo "Will run mkgarf for the same ${chip_name} list "
echo "   "

runMkgarf $detsubsys
echo "   "
echo "Finished processing grating arfs for ${chip_name}= ${chiplist} "
echo "   "

runDmarfadd

echo "  "
echo "$0 finished. "
echo "  "

### See the note above regarding the redundancy
### that results when the user sets mode="ql"
if [ "$mode_orig" = "ql" ]; then
 pset $pacc mode="ql"
fi

exit 0
