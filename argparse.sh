#!/bin/bash
#
# changelog
#  2021-04-10 :: Created
#  2021-04-14 :: Proof of concept test with static data completed
#  2021-04-16 :: Improved sourcing dependencies, using new .buf methods to
#                streamline one-off line printing

#──────────────────────────────────( prereqs )──────────────────────────────────
# Version requirement: >4
_bash_version="$( sed -E 's,^([0-9]+)\..*,\1,' <<< "${BASH_VERSION}" )"
[[ $_bash_version -lt 4 ]] && {
   echo -e "\n[${BASH_SOURCE[0]}] ERROR: Requires Bash version >= 4\n"
   exit 1
}

# Verification if we've sourced this in other scripts. Name is standardized.
# e.g., filename 'mk-conf.sh' --> '__source_mk_conf=true'
__fname__="$( basename "${BASH_SOURCE[0]%.*}" )"
declare $(
      sed -E -e 's,(.*),__source_\1__,' -e 's,-,_,g' <<< "${__fname__}"
)=true

# Ensure we're not left with a whacky terminal color:
trap 'printf $(tput sgr0)' EXIT
trap 'printf $(tput sgr0) ; exit 0' INT


#══════════════════════════════════╡ GLOBALS ╞══════════════════════════════════
PROGDIR=$( cd $(dirname "${BASH_SOURCE[0]}") ; pwd )
LIBDIR="${PROGDIR}/lib"
CONFIGDIR="${PROGDIR}/config"


#═══════════════════════════╡ SOURCING DEPENDENCIES ╞═══════════════════════════
# from colors  import <color escapes>
# from indent  import .buf
# from mk-conf import .load-conf

__dependencies__=( colors.sh  mk-conf.sh  indent.sh )
__dep_not_met__=()

for __dep__ in "${__dependencies__[@]}" ; do
   #───────────────────────────( already sourced )──────────────────────────────
   # If we've already sourced this dependency, its respective __sourced_XX var
   # will be set. Don't re-source. Continue.
   __dep_sourcename__="$(
         sed -E -e 's,-,_,g' -e 's,(.*)\.sh,__source_\1__,' <<< "$__dep__"
   )" 
   [[ -n "${!__dep_sourcename__}" ]] && continue

   #─────────────────────────────( try source )─────────────────────────────────
   if [[ -e "${LIBDIR}/${__dep__}" ]] ; then
      source "${LIBDIR}/${__dep__}"
   elif [[ $(which ${__dep__} 2>/dev/null) ]] ; then
      # Else try to source if the file is found in our $PATH
      source "$(which ${__dep__})"
   else
      # Else failed to source. Append to list for tracking.
      __dep_not_met__+=( "$__dep__" )
   fi
done

if [[ ${#__dep_not_met__} -gt 0 ]] ; then
   # If colors have been sourced, pretty-print output
   if [[ -n $__source_colors__ ]] ; then
      echo -n "[${bl}${__fname__}${rst}] ${brd}ERROR${rst}: "
   # ELse just regular plain-print it. :(
   else
      echo -n "[$__fname__] ERROR: "
   fi

   echo "Failed to source: [${__dep_not_met__[@]}]"
   echo " + clone from @hre-utils"

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
         _meta=$(args $opt meta)
         _meta=${_meta:-${opt^^}}
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
         _meta=$(args $opt meta)
         _meta=${_meta:-${opt^^}}
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

. <(
   #────────────────────────────────( begin )───────────────────────────────────
   .buf new
   .buf config --strip-newlines

   echo 'while [[ $# -gt 0 ]] ; do'
   echo '   case $1 in'

   #─────────────────────────( dynamic generation )─────────────────────────────
   # Dynamically generates an "-a|--alpha)" entry for each heading under [args],
   # building the correct case body depending on the attrs. E.g., 'param' will
   # require there's a non-option argument.
   .buf oneoff 6 "
      -h|--help)
            usage 0
            ;;
   "


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
)


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
