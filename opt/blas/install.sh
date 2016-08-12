#!/bin/bash
NAME=BLAS


UNAME=`echo $NAME |tr [:lower:] [:upper:]`
LNAME=`echo $NAME |tr [:upper:] [:lower:]`
LIBNAME=lib$LNAME.a
LOG=install.log
>$LOG
exec >  >(tee -a $LOG)
exec 2> >(tee -a $LOG >&2)


#>>> USAGE FUNCTION
usage(){
    echo ""
    echo "usage:"
    echo ""
    echo "$0  -p,--plat=FC_PLAT --prefix=PREFIX_DIR  [ -c,--clean -d,--debug  -h,--help ]"
    echo ""
    echo "    -p,--plat   : specifies the actual platform/compiler to use [intel,gnu]"
    echo "    --prefix    : specifies the target directory [default: FC_PLAT]"
    echo "    -q,--quiet  : assume Y to all questions."
    echo "    -c,--clean  : clean out the former compilation."
    echo "    -d,--debug  : debug flag"
    echo "    -h,--help   : this help"
    echo ""
    exit
}



#>>> GET Nth TIMES PARENT DIRECTORY
nparent_dir(){
    local DIR=$1
    local N=$2
    for i in `seq 1 $N`;
    do 
	DIR=$(dirname $DIR)
    done
    echo $DIR
}

#>>> GET THE ENTIRE LIST OF ARGUMENTS PASSED TO STDIN
LIST_ARGS=$*

#>>> GET LONG & SHORT OPTIONS
params="$(getopt -n "$0" --options p:o:qcwdh --longoptions plat:,prefix:,opt-lib:,quiet,clean,wdmftt,debug,help -- "$@")"
if [ $? -ne 0 ];then
    usage
fi
eval set -- "$params"
unset params

#>>> CHECK THE NUMBER OF ARGUMENTS. IF NONE ARE PASSED, PRINT HELP AND EXIT.
NUMARGS=$#
if [ $NUMARGS -eq 0 ]; then
    usage
fi



#>>> SET SOME DEFAULTS VARIABLES AND OTHER ONES
WPLAT=1
DEBUG=1
CLEAN=1
WRK_INSTALL=$(pwd)
BIN_INSTALL=$WRK_INSTALL/bin
ETC_INSTALL=$WRK_INSTALL/etc
OPT_INSTALL=$WRK_INSTALL/opt
ENVMOD_INSTALL=$ETC_INSTALL/environment_modules
SRC_INSTALL=$WRK_INSTALL/src


#>>> THE LISTS OF ALLOWED PLAT
LIST_FC="gnu intel"


#>>> GO THROUGH THE INPUT ARGUMENTS. FOR EACH ONE IF REQUIRED TAKE ACTION BY SETTING VARIABLES.
while true
do
    case $1 in
	-p|--plat)
	    WPLAT=0
	    PLAT=$2
	    shift 2
	    [[ ! $LIST_FC =~ (^|[[:space:]])"$PLAT"($|[[:space:]]) ]] && {
		echo "Incorrect Fortran PLAT: $PLAT";
		echo " available values are: $LIST_FC"
		exit 1
	    }
	    ;;
	--prefix)
	    PREFIX=$2;
	    shift 2
	    ;;
	-c|--clean) CLEAN=0;shift ;;
	-d|--debug) DEBUG=0;shift ;;
        -h|--help) usage ;;
	-q|--quiet) shift ;;
        --) shift; break ;;
        *) usage ;;
    esac
done

#>>> CHECK THAT THE MANDATORY OPTIONS ARE PRESENT:
[[ $WPLAT == 0 ]] && [[ ! -z $PREFIX ]] || usage



#RENAME WITH DEBUG IF NECESSARY 
if [ $DEBUG == 0 ];then 
    PLAT=${PLAT}_debug;
fi

#>>> SET STANDARD NAMES FOR THE TARGET DIRECTORY
DIR_TARGET=$PREFIX/$PLAT
BIN_TARGET=$DIR_TARGET/bin
ETC_TARGET=$DIR_TARGET/etc
LIB_TARGET=$DIR_TARGET/lib
INC_TARGET=$DIR_TARGET/include
OBJ_INSTALL=$SRC_INSTALL/obj_$PLAT

create_makeinc(){    
    local PLAT=$1
    cd $WRK_INSTALL
    case $PLAT in
	intel)
	    local FC=ifort
	    local FFLAGS='-O2 -ftz -static-intel'
	    local MOPT=-module 
	    ;;
	gnu)
	    local FC=gfortran
	    local FFLAGS='-O2 -funroll-all-loops -static'
	    local MOPT=-J
	    ;;
	intel_debug)
	    local FC=ifort
	    local FFLAGS='-p -O0 -g -debug -fpe0 -traceback -check all,noarg_temp_created -static-intel'
	    local MOPT=-module 
	    ;;
	gnu_debug)
	    FC=gfortran
	    FFLAGS='-O0 -p -g -Wall -fbacktrace -static'
	    ;;
	*)
	    usage
	    ;;
    esac
    
    cat << EOF > make.inc
SHELL = /bin/sh
PLAT = $PLAT
OBJ_INSTALL=$OBJ_INSTALL
#  
#  Modify the FORTRAN and OPTS definitions to refer to the
#  compiler and desired compiler options for your machine.  NOOPT
#  refers to the compiler options desired when NO OPTIMIZATION is
#  selected.  Define LOADER and LOADOPTS to refer to the loader
#  and desired load options for your machine.
#
FORTRAN = $FC
OPTS     = $FFLAGS 
DRVOPTS  = $OPTS
NOOPT    = -O0
LOADER   = $FC
LOADOPTS = 

# Timer for the SECOND and DSECND routines
# TIMER     = NONE
#
#  The archiver and the flag(s) to use when building archive (library)
#  If you system has no ranlib, set RANLIB = echo.
#
ARCH     = ar
ARCHFLAGS= cr
RANLIB   = ranlib
#
#  The location of BLAS library for linking the testing programs.
#  The target's machine-specific, optimized BLAS library should be
#  used whenever possible.
#
BLASLIB      = $LIB_TARGET/$LIBNAME
#
#  Location of the extended-precision BLAS (XBLAS) Fortran library
#  used for building and testing extended-precision routines.  The
#  relevant routines will be compiled and XBLAS will be linked only if
#  USEXBLAS is defined.
#
# USEXBLAS    = Yes
XBLASLIB     =
# XBLASLIB    = -lxblas
#
#  Names of generated libraries.
#
LAPACKLIB    = lapack$PLAT.a
TMGLIB       = tmglib$PLAT.a
EIGSRCLIB    = eigsrc$PLAT.a
LINSRCLIB    = linsrc$PLAT.a

EOF
}


create_makeinc $PLAT
sleep 1
if [ $CLEAN == 0 ];then
    make cleanall
    exit 0
fi


echo "Installing in $DIR_TARGET."
sleep 2


echo "Creating directories:"
mkdir -pv $DIR_TARGET
mkdir -pv $BIN_TARGET
mkdir -pv $ETC_TARGET/modules/$LNAME
mkdir -pv $LIB_TARGET
mkdir -pv $INC_TARGET
mkdir -pv $OBJ_INSTALL
sleep 1


# echo "Copying init script for $UNAME" 
# cp -fv $BIN_INSTALL/configvars.sh $BIN_TARGET/configvars.sh
# cat <<EOF >> $BIN_TARGET/configvars.sh
# add_library_to_system ${PREFIX}/${PLAT}
# EOF
# echo "" 
# sleep 1

echo "Generating environment module file for $UNAME" 
cat <<EOF > $ETC_TARGET/modules/$LNAME/$PLAT
#%Modules
set	root	$PREFIX
set	plat	$PLAT
set	version	"$VERSION ($PLAT)"
EOF
cat $ENVMOD_INSTALL/module >> $ETC_TARGET/modules/$LNAME/$PLAT
echo "" 
sleep 1


echo "Compiling $UNAME library on platform $PLAT:"
echo "" 
sleep 1

# if [ -d $OBJ_INSTALL ];then
#     rsync -av $OBJ_INSTALL/* $SRC_INSTALL/ 2>/dev/null
# fi
make
if [ $? == 0 ];then
    #make clean
    make cleanall
    mv -vf $WRK_INSTALL/make.inc $ETC_TARGET/make.inc.blas
else
    echo "Error from Makefile. STOP here."
    exit 1
fi
rsync -av $WRK_INSTALL/share/man $PREFIX/$PLAT/ > /dev/null 2>&1

exit 0