##
## File       : fsmfuncs.sh
## Author     : Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: useful shell functions for AT&T fsm tools

##----------------------------------------------------------------------
## Information

## y_or_n=`fsm_is_transducer $afsmfile`
fsm_is_transducer() {
  fsminfo "$@" | grep '^transducer' | cut -f2
}

## flags=`fsm2gfsm_compile_flags $afsmfile`
fsm2gfsm_compile_flags() {
  if test `fsm_is_transducer "$@"` != "y" ; then
    echo "-a"
  fi
}

##----------------------------------------------------------------------
## temp files

## filename=`fsm_tempfile PREFIX SUFFIX`
fsm_tempfile() {
  if test -z `which tempfile 2>/dev/null` ; then
   tempfile --prefix="$1" --suffix="$2"
  else
    echo "/tmp/$1_$$$2"
  fi
}

##----------------------------------------------------------------------
## labels & symbols

## symbase=`fsm_symbase $lab_or_scl_or_sym_file`
fsm_symbase() {
  echo "$1" | sed -e's/\.\(lab\|scl\|sym\)$//1'
}

## labargs=`fsm_labargs $symbase_or_file`
fsm_labargs() {
  echo "-l "`fsm_symbase "$1"`".lab -S "`fsm_symbase "$1"`".scl"
}

## iolabs=`fsm_ioargs $symbase_or_file`
fsm_iolabs() {
  echo "-i "`fsm_symbase "$1"`".lab -o "`fsm_symbase "$1"`".lab"
}
