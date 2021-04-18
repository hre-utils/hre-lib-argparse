#!/bin/bash
# main.sh, to test sourcing argparse for argument handling.

PROGDIR="$( cd $(dirname "${BASH_SOURCE[0]}") ; pwd )"
source "${PROGDIR}/argparse.sh"

echo # for spacing

declare -a table
(
   for opt in $(args __children__) ; do
      echo -e "${opt}\t${!opt}"
   done
) | column -t -s $'\t' -o ' : '

echo -en "\nPositional: ["
for idx in "${!__positional__[@]}" ; do
   val="${__positional__[$idx]}"
   sep=','
   [[ $val -eq $(( ${#__positional__[@]} - 1 )) ]] && sep=''

   echo -en "'$val'${sep}"
done
echo -e "]\n"
