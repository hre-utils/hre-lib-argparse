#!/bin/bash
#
# changelog
#  2021-04-10 :: Created
#  2021-04-14 :: Proof of concept test with static data completed
#
#════════════════════════════════╡ DESCRIPTION ╞════════════════════════════════
#───────────────────────────────────────────────────────────────────────────────

# Colors:
rst=$(tput sgr0)                          # Reset
bk="\033[30m"                             # Black
rd="\033[31m"     ; brd="\033[31;1m"      # Red    / Bright Red
gr="\033[32m"     ; bgr="\033[32;1m"      # Green  / Bright Green
yl="\033[33m"     ; byl="\033[33;1m"      # Yellow / Bright Yellow
bl="\033[34m"     ; bbl="\033[34;1m"      # Blue   / Bright Blue
cy="\033[36m"     ; bcy="\033[36;1m"      # Cyan   / Bright Cyan
wh="\033[37m"     ; bwh="\033[37;1m"      # White  / Bright White

# Ensure we're not left with a whacky terminal color:
trap 'printf $rst' EXIT
trap 'printf $rst ; exit 0' INT


#───────────────────────────────────( paths )───────────────────────────────────
# Sets up all required paths.

# If file is linked from this repo to another dir (~/bin, /usr/local/bin/, etc),
# it will still properly source files relative to the $PROGDIR:
if [[ -L "${BASH_SOURCE[0]}" ]] ; then
   PROGDIR=$( cd $(dirname $(readlink -f  "${BASH_SOURCE[0]}")) ; pwd )
else
   PROGDIR=$( cd $(dirname "${BASH_SOURCE[0]}") ; pwd )
fi

LIBDIR="${PROGDIR}/lib"
CONFIGDIR="${PROGDIR}/config"


#────────────────────────────( source dependencies )────────────────────────────
# Don't actually think we need to source all the dependencies, as each one
# sequentially sources the next in the list.

declare -a __dep_not_met__
declare -a __dependencies__=(
   mk-conf.sh
   indent.sh
)

for __dep__ in "${__dependencies__[@]}" ; do
   if [[ -d "$LIBDIR" ]] && [[ -e "${LIBDIR}/${__dep__}" ]] ; then
      source "${LIBDIR}/${__dep__}" 
   else
      __dep_not_met__+=( ${__dep__} )
   fi
done

if [[ ${#__dep_not_met__} -gt 0 ]] ; then
   # Using bash parameter regex, raerpb calls to `sed`, to squeek out more
   # speed. Subprocesses add up.
   __deps_wout_suffix__="${__dep_not_met__[*]%.*}" 
   __deps_joined__=${__deps_wout_suffix__[*]// /,}

   echo "Dependencies not found in ./$( basename ${PROGDIR})/lib/ or \$PATH:"
   echo "   @hre-utils/{${__deps_joined__}}"
   exit 1
fi


#───────────────────────────────( load args.cfg )───────────────────────────────
# Loads config and dynamically creates functions for each heading, top-level
# headings are given simple, user-callable names. Subheadings must be accessed
# by calling `heading subheading1 subheading2` to traverse the tree.
.load-conf "${CONFIGDIR}/args.cfg"

#────────────────────────────( establish required )─────────────────────────────
# could do this as part of the lower loop, but for clarity i feel it's better
# to leave here.

declare -a __required_opts__ __nonreq__opts__
declare -a opts=( $(args __children__) )

__rp__=''      # required + param
__nrp__=''     # not required + param
__nrnp__=''    # not required + no param

# todo: no need for required + no param, as that's not an option, it's an
#       always-on default setting. this should be covered in the validation
#       stage, where we can parse the config file and yell at the user for dumb
#       settings.

for opt in "${opts[@]}" ; do
   # Required options:
   if $(args $opt required) ; then
      __required_opts__+=( $opt )

      if $(args $opt param) ; then
      #──────────────────────────( req & param )────────────────────────────────
         _meta=$(args \$opt meta)
         _meta=${_meta:-\${opt^^}}
         __rp__+="$(args $opt short) ${_meta}" 
      else
      #─────────────────────────( req & noparam )───────────────────────────────
         # TODO: this should be part of the validation, not echo'd at runtime.
         echo -e "\nWARN: '$(args $opt short)' required & no param isn't an 'option'.\n"
      fi
   # Non-required options:
   else
      __nonreq__opts__+=( $opt )

      if $(args $opt param) ; then
      #─────────────────────────( noreq & param )───────────────────────────────
         _meta=$(args \$opt meta)
         _meta=${_meta:-\${opt^^}}
         __nrp__+="[$(args $opt short) ${_meta}] "
      else
      #────────────────────────( noreq & noparam )──────────────────────────────
         _short=$(args $opt short) 
         __nrnp__+=${_short#-}
      fi
   fi
done

# Compile the 'abcd' options into "[-abcd]"
__nrnp__="${__nrnp__:+[-${__nrnp__}]} "


#════════════════════════════════╡ BUILD USAGE ╞════════════════════════════════
. <(
   #────────────────────────────────( begin )───────────────────────────────────
   echo "
   function usage {
   #─────────────────────────────( title opts )─────────────────────────────────
   echo -e \"\\nUSAGE: ./${BASH_SOURCE[@]} ${__nrnp__}${__nrp__}${__rp__}\"

   #─────────────────────────────( description )────────────────────────────────
   # Description is easy, make heading \"description:multiline\", then pull
   # echo \$(description multiline)
   # Though I should probably write some processing here to ensure we don't go
   # past 80 lines. Wrap & justify if so. The justification math is going to be
   # a project in and of itself.
   echo -e \"\\nDescription: This is a placeholder description for how this project do, and what
it is. Beep boop. Here's some more text.\\n\"

   #──────────────────────────────( required )──────────────────────────────────
   echo \"Required:\"
   
   declare -a __f_req__=()
   for opt in \"\${__required_opts__[@]}\" ; do
      _meta=\$(args \$opt meta)
      _meta=\${_meta:-\${opt^^}}
      __f_req__+=( \"\$(args \$opt short) \${_meta}|\$(args \$opt text)\" )
   done

   for row in \"\${__f_req__[@]}\" ; do
      printf \"   %s\\n\" \"\$row\"
   done | column -ts $'|' -o \"  |  \"

   #────────────────────────────( non-required )────────────────────────────────
   echo -e \"\\nOptional:\"

   declare -a __f_nreq__=()
   for opt in "\${__nonreq__opts__[@]}" ; do
      if \$(args \$opt param) ; then
         _meta=\$(args \$opt meta)
         _meta=\${_meta:-\${opt^^}}
         __f_nreq__+=( \"\$(args \$opt short) \${_meta}|\$(args \$opt text)\" )
      else
         __f_nreq__+=( \"\$(args \$opt short)|\$(args \$opt text)\" )
      fi
   done

   for row in \"\${__f_nreq__[@]}\" ; do
      printf \"   %s\\n\" \"\$row\"
   done | column -ts $'|' -o \"  |  \"

   echo

   #─────────────────────────────────( end )────────────────────────────────────
   exit \$1
   }
   "
)

#═══════════════════════════╡ BUILD CASE STATEMENT ╞════════════════════════════
# Creates the standard while/case/shift CLI arg parsing, but from a dynamic set
# of options not known until runtime.

#. <(
   #────────────────────────────────( begin )───────────────────────────────────
   .buf new
   echo 'while [[ $# -gt 0 ]] ; do'
   echo '   case $1 in'

   #─────────────────────────( dynamic generation )─────────────────────────────
   # Dynamically generates an "-a|--alpha)" entry for each heading under [args],
   # building the correct case body depending on the attrs. E.g., 'param' will
   # require there's a non-option argument.
   .buf add "
      -h|--help)
            usage 0
            ;;
   " ; .buf indent 6 ; .buf reset


   for opt in "${opts[@]}" ; do
      sopt=$(args $opt short)
      lopt=$(args $opt long)

      # THINKIES:
      # TODO: This requires that a short option is present, but not a long one.
      #       We should probably enforce some constraints on the data that's
      #       passed in. Perhaps multiple passes to check for different things?
      #       They're all just function calls echo'ing data, so it shouldn't be
      #       that much of a performance hit.
      #       I wonder, do we want to ensure that every opt has a short name?
      #       Can there be long-only opts? It may be helpful for a utility with
      #       many commands, some of which not fitting into a-zA-Z cleanly.
      echo -e "      ${sopt}${lopt:+|$lopt}) shift"

      if $(args $opt param) ; then
         .buf push "
            if [[ \$1 == -* ]] || [[ -z \$1 ]] ; then
               echo \"\\\$1 :: \$1\"
               __missing_param__+=( $opt )
               continue 
            fi

            $opt=\$1 
            shift
         "
      else
         .buf push  "$opt=true"
      fi

      .buf push ";;"
      .buf indent 9
      .buf reset
   done

   #────────────────────────( misc. arg processing  )───────────────────────────
   # My boilerplate argparse section. Covers:
   #  1. expanding combined short opts: "-abc" -> "-a -b -c"
   #  2. unsupported, positional, or '--' support
   .buf reset
   .buf push "
      -[^-]*)
         _opts=( \$( grep -o . < <(sed 's,^-,,' <<< \$1) ) )
         for _idx in \"\${!_opts[@]}\" ; do
            _opts[\$_idx]=\"-\${_opts[\$_idx]}\"
         done

         shift

         [[ \${#_opts[@]} -eq 1 ]] && {
            __unsupported__+=( \${_opts[0]} )
            continue
         }

         set -- \${_opts[@]} \$@
         ;;

      --)   shift ; break ;;
      --*)  __unsupported__+=( \$1 ) ; shift ;;
      *)    __positional__+=( \$1 ) ; shift ;; 
   " ; .buf indent 6

   echo -e "   esac"
   echo -e "done\n"
   echo "__positional__+=( \$@ )"
#)



#────────────────────────────────( validation )─────────────────────────────────


declare -a __validation_errors__ 

[[ ${#__missing_param__[@]} -gt 0 ]] && {
   __validation_errors__+=(
      "Missing param: '${__missing_param__[*]}'"
   )
}

[[ ${#__unsupported__[@]} -gt 0 ]] && {
   __validation_errors__+=(
      "Unsupported: '${__unsupported__[*]}'"
   )
}

# Not a great way to check required opts, as we can double up in a case like:
#  -b == required, with parameter
# User passes in `-b` with no param. This will count as both a missing required
# param, as well as a missing param. Kinda weird to get a very similar message
# twice for the same param.
for _opt in "${__required_opts__[@]}" ; do
   if [[ -z ${!_opt} ]] ; then
      __missing_required__+=( ${_opt} )
   fi
done

[[ ${#__missing_required__[@]} -gt 0 ]] && {
   __validation_errors__+=(
      "Missing required: '${__missing_required__[*]}'"
   )
}

#──────────────────────────────────( results )──────────────────────────────────
[[ ${#__validation_errors__[@]} -gt 0 ]] && {
   echo "───────────────────────────────────( errors )───────────────────────────────────"
   for _idx in "${!__validation_errors__[@]}" ; do
      _err="${__validation_errors__[$_idx]}" 
      echo " $(($_idx+1)). ${_err}"
   done
   echo "───────────────────────────────────(  done  )───────────────────────────────────"
   usage 1
}
