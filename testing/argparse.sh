#!/bin/bash
# argparse.sh
# v0.1, 2021-04-05
#
#═══════════════════════════════════╡ TODO ╞════════════════════════════════════
# What about changing the 'public methods' from underscore prefixed to .-prefix,
# for example:
#  opts=( $(args .children) )  vs.  opts=( $(args __children__) )

if [[ -L "${BASH_SOURCE[0]}" ]] ; then
   PROGDIR=$( cd $(dirname $(readlink -f  "${BASH_SOURCE[0]}")) ; pwd )
else
   PROGDIR=$( cd $(dirname "${BASH_SOURCE[0]}") ; pwd )
fi

source "${PROGDIR}/conf_parse.sh"
.load-conf "${PROGDIR}/args.cfg"

function contains {
   search=$1 ; shift
   [[ $@ == *$search* ]]
}

declare _shortopts _longopts
declare -a _reqopts
declare -A _shoptmap _loptmap

for opt in $(args __children__) ; do
   _shortopts+=${_shortopts:+|}$(args $opt short)
   _shoptmap[$(args $opt short)]=$opt

   _longopts+=${_longopts:+|}$(args $opt long)
   _loptmap[$(args $opt long)]=$opt

   declare $opt=false
   $(args $opt required) && _reqopts+=( $opt )
done

# THINK: aight, what if we do something like:
#source <(echo "echo test")
# Or maybe a `. <(cat <<EOF ...)`
# Testing this approach in ../metaprogramming/dynamic_case.sh

while [[ $# -gt 0 ]] ; do
   eval "
   case \$1 in
      $_shortopts)
         opt=\${_shoptmap[\$1]}
         shift
         if \$(args \$opt param) ; then
            [[ -z \$1 ]] || [[ \1 == --* ]] || [[ \1 && {
               __missing_parameters__+=( \${opt^^} )
               continue
            }
            eval \$opt=\$1 ; shift
         else
            eval \$opt=true
         fi
         ;;
      $_longopts)
         opt=\${_loptmap[\$1]}
         shift
         if \$(args \$opt param) ; then
            eval \$opt=\$1
            shift
         else
            eval \$opt=true
         fi
         ;;
      *) __unsupported__+=( \$1 ) ; shift ;; 
   esac
   "
done

declare -a __validation_errors__


for _err in "${__validation_errors__[@]}" ; do
   echo "   $_err"
done

if [[ ${__unsupported__[@]} -gt 0 ]] ; then
   echo "Unsupported arguments"
   for _unsupp in "${__unsupported__[@]}" ; do
      echo "   $_unsupp"
   done
fi

for _opt in "${_reqopts[@]}" ; do
   $_opt 2>/dev/null || echo "Missing required opt: ${_opt}"
done
