#!/bin/bash
# Testing dynamic case statement generation with bash metaprogramming
#
# I think we're running into errors because it's trying to re-define 'alpha',
# 'bravo', etc.. I didn't mimic exactly how the other functionality works, waus
# in my other script, none of these would exist as actual functions. They'd be
# under 'args' (i.e., $(args alpha), $(args bravo), ...)
#
# I think it's throwing off the later CLI processing.


#───────────────────────( simulate parsed conf options )────────────────────────
# Something resembling these functions would've been built by our from_conf and
# mk_class scripts. Hard-coding here for ease of use:

declare -a opts=(
   alpha
   bravo
   charlie
)

function alpha {
   [[ $1 == 'short'    ]]  && echo "-a"         && return 0
   [[ $1 == 'long'     ]]  && echo "--alpha"    && return 0
   [[ $1 == 'text'     ]]  && echo "Here is the help text for this function" && return 0
   [[ $1 == 'required' ]]  && return 1
   return 1
}

function bravo {
   [[ $1 == 'short'    ]]  && echo "-b"         && return 0
   [[ $1 == 'long'     ]]  && echo "--bravo"    && return 0
   [[ $1 == 'text'     ]]  && echo "Use bravo for things" && return 0
   [[ $1 == 'param'    ]]  && return 0
   [[ $1 == 'required' ]]  && return 0
   return 1
}

function charlie {
   [[ $1 == 'short'    ]]  && echo "-c"         && return 0
   [[ $1 == 'long'     ]]  && echo "--charlie"  && return 0
   [[ $1 == 'text'     ]]  && echo "CHARLIE IS THE 3RD" && return 0
   [[ $1 == 'required' ]]  && return 1
   return 1
}


# TODO: This works, although every single line has 2 calls to `sed`, and 1
#       `grep`. There is a very noticable delay when running. Should swap
#       as many as possible with bash's native regex, rather than external
#       calls.

function indt {
   # Any line indented than the first will default to the indentation of the
   # first line.
   level=$1 ; shift

   buffer=''
   declare -i init_idnt

   while IFS=$'\n' read -r line ; do
      # TODO: Do we actually want to strip empty lines? Could be useful to
      #       leave them in for a bit nicer formatting.
      [[ $line == $'\n' ]] && continue
      [[ $line == '' ]]    && continue
      
      # Replaces initial spaces with periods, then uses `grep` to list each
      # period on a new line, and `wc` to count each line. Hacky way of saying
      # "count the leading spaces".
      mark_spaces=$( sed -E -e 's,^(\s*).*,\1,g' -e 's,\s,.,g' <<< $line )
      cur_idnt=$( wc -l < <(grep -o '.' <<< $mark_spaces) ) 

      # If it's the first line, log the indentation level, so we know how much
      # to strip off future lines:
      init_idnt=${init_idnt:-$cur_idnt}
      idnt=$(( cur_idnt - init_idnt + $level ))

      # Strip initial whitespace, then restore the correct amount
      stripped_line="$(sed -E 's,^\s+,,' <<< $line)"
      add_correct_idnt=$(printf "%${idnt}s%s\n"   " "   "$stripped_line")

      # Append the new line to our new lines 'buffer'. If there's already text
      # in the buffer, preceed the new text with a newline.
      buffer+="${buffer:+\n}${add_correct_idnt}"
   done <<< "$@"

   echo -e "$buffer"
}


#────────────────────────────( establish required )─────────────────────────────
# could do this as part of the lower loop, but for clarity i feel it's better
# to leave here.

declare -a __required_opts__ __nonreq__opts__

__rp__=''      # required + param
__nrp__=''     # not required + param
__nrnp__=''    # not required + no param

# todo: no need for required + no param, as that's not an option, it's an
#       always-on default setting. this should be covered in the validation
#       stage, where we can parse the config file and yell at the user for dumb
#       settings.

for opt in "${opts[@]}" ; do
   # Required options:
   if $($opt required) ; then
      __required_opts__+=( $opt )

      if $($opt param) ; then
      #──────────────────────────( req & param )────────────────────────────────
         _meta=$( $($opt meta) || echo ${opt^^} )
         __rp__+="$($opt short) ${_meta}" 
      else
      #─────────────────────────( req & noparam )───────────────────────────────
         # TODO: this should be part of the validation, not echo'd at runtime.
         echo -e "\nWARN: '$($opt short)' required & no param isn't an 'option'.\n"
      fi
   # Non-required options:
   else
      __nonreq__opts__+=( $opt )

      if $($opt param) ; then
      #─────────────────────────( noreq & param )───────────────────────────────
         _meta=$( $($opt meta) || echo ${opt^^} )
         __nrp__+="[$($opt short) ${_meta}] "
      else
      #────────────────────────( noreq & noparam )──────────────────────────────
         _short=$($opt short) 
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
      _meta=\$( \$(\$opt meta) && echo \$(\$opt meta) || echo \${opt^^} )
      __f_req__+=( \"\$(\$opt short) \${_meta}|\$(\$opt text)\" )
   done

   for row in \"\${__f_req__[@]}\" ; do
      printf \"   %s\\n\" \"\$row\"
   done | column -ts $'|' -o \"  |  \"

   #────────────────────────────( non-required )────────────────────────────────
   echo -e \"\\nOptional:\"

   declare -a __f_nreq__=()
   for opt in "\${__nonreq__opts__[@]}" ; do
      if \$(\$opt param) ; then
         _meta=\$( \$(\$opt meta) && echo \$(\$opt meta) || echo \${opt^^} )
         __f_nreq__+=( \"\$(\$opt short) \${_meta}|\$(\$opt text)\" )
      else
         __f_nreq__+=( \"\$(\$opt short)|\$(\$opt text)\" )
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
   echo 'while [[ $# -gt 0 ]] ; do'
   echo '   case $1 in'

   #─────────────────────────( dynamic generation )─────────────────────────────
   # Dynamically generates an "-a|--alpha)" entry for each heading under [args],
   # building the correct case body depending on the attrs. E.g., 'param' will
   # require there's a non-option argument.

   for opt in "${opts[@]}" ; do
      sopt=$($opt short)
      lopt=$($opt long)

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

      if $($opt param) ; then
         indt 12 "
            if [[ \$1 == -* ]] || [[ -z \$1 ]] ; then
               echo \"\\\$1 :: \$1\"
               __missing_param__+=( $opt )
               continue 
            fi

            $opt=\$1 
            shift"
      else
         indt 12  "$opt=true"
      fi

      indt 12 ";;"
   done

   #────────────────────────( misc. arg processing  )───────────────────────────
   # My boilerplate argparse section. Covers:
   #  1. expanding combined short opts: "-abc" -> "-a -b -c"
   #  2. unsupported, positional, or '--' support
   indt 6 "
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
   "

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

for opt in "${opts[@]}" ; do
   eval "echo $opt :: ${!opt}"
done

echo "positionals:"
for p in "${__positional__[@]}" ; do
   echo -e "\t'$p' "
done
