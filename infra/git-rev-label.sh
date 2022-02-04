#!/usr/bin/env bash

## Repo https://gitlab.com/kyb/git-rev-label
## Install and Update with:
##   curl 'https://gitlab.com/kyb/git-rev-label/raw/artifacts/master/git-rev-label' -Lf -o git-rev-label  &&  chmod +x git-rev-label
##   wget 'https://gitlab.com/kyb/git-rev-label/raw/artifacts/master/git-rev-label' -qO git-rev-label  &&  chmod +x git-rev-label
## To make this command work as git subcommand `git rev-label` create link to this script in PATH:
##   ln -s $PWD/git-rev-label.sh /usr/local/bin/git-rev-label
## Then use it
##   git rev-label
## or
##   git rev-label '$refname-c$count-g$short$_dirty'

set -eEuo pipefail
shopt -s inherit_errexit
shopt -s lastpipe
shopt -s expand_aliases

VERSION=master-c16-g154e93e-b14
VERSION_NPM=2.16.14

function echomsg      { echo $'\e[1;37m'"$@"$'\e[0m'; }
function echodbg  { >&2 echo $'\e[0;36m'"$@"$'\e[0m'; }
function echowarn { >&2 echo $'\e[0;33m'WARNING$'\e[0m' "$@"; }
function echoerr  { >&2 echo $'\e[0;31m'ERROR$'\e[0m' "$@"; }
function fatalerr { >&2 echoerr "$@"; exit 1; }

if test `uname` == Darwin ;then
   alias sed=gsed
   alias grep=ggrep
   alias find=gfind
   alias date=gdate
   alias cp=gcp
   alias mv=gmv
   alias ls=gls
   alias mktemp=gmktemp
   alias readlink=greadlink
fi

function OnErr { caller | { read lno file; echoerr ">ERR in $file:$lno,  $(sed -n ${lno}p $file)" >&2; };  }
trap OnErr ERR

is_sourced(){
   [[ "${BASH_SOURCE[0]}" != "${0}" ]]
}

var_is_set(){
   declare -rn var=$1
   ! test -z ${var+x}
}
var_is_set_not_empty(){
   declare -rn var=$1
   ! test -z ${var:+x}
}
var_is_unset(){
   declare -rn var=$1
   test -z ${var+x}
}
var_is_unset_or_empty(){
   declare -rn var=$1
   test -z ${var:+x}
}

# a=$(false; echo 123;) #|| fatalerr "break"
# echodbg 123
# false

function --help {
   echo -n \
'Gives information about Git repository revision in format like '"'master-c73-gbbb6bec'"'.
Can fill template string or file with environment variables and information from Git. 
Useful to provide information about version of the program: branch, tag, commit hash, 
commits count, dirty status, date and time. One of the most useful things is count of 
commits, not taking into account merged branches - only first parent.

USAGE:
   git rev-label
   git rev-label [--help|-h|-?]
   git rev-label [--version|-V]
   git rev-label '"'"'$refname-c\$count-g\$short\$_dirty'"'"'
   git rev-label --format="`cat build_info.template.h`"
   git rev-label --format-file=build_info.template.h
   git rev-label --format-from=version-template.json  ## Alias to --format-file
   git rev-label --variables
   eval $(git rev-label --variables | sed s,^,export\ ,)  ## Export variables to environment

COMPLEX USE CASE:
 * Fill `build_info.template.h` with branch, tag, commit hash, commits count, dirty status. 
   Than include result header to access build information from code. 
   See https://gitlab.com/kyb/git-rev-label/blob/master/build_info.template.h and
   https://gitlab.com/kyb/git-rev-label/blob/master/create-build-info.sh

INSTALLATION:
   ./git-rev-label --install|--install-link [--install-dir=/usr/local/bin]

UPDATE:
   git rev-label --update

More info at https://gitlab.com/kyb/git-rev-label
'
}
function --version {
   echo "git-rev-label v$VERSION_NPM 
   $VERSION
   https://gitlab.com/kyb/git-rev-label"
}
-V(){ echo "git-rev-label v$VERSION_NPM"; }
function --rev-label {
   echo "$VERSION"
}
--rev(){ --rev-label "$@"; }
--version-npm(){ echo $VERSION_NPM; }
--npm-version(){ --version-npm "$@"; }

set_with_warn(){
   varname=$1
   shift
   var_is_set $varname  && echowarn "!!! $varname already set to '${!varname}'. Overriding"
   declare -g $varname="$@"
}
set_action(){
   set_with_warn action $1
}

readonly FULL_LIST="commit short SHORT  long LONG  count  COUNT  dirty _dirty DIRTY _DIRTY  tag branch refname"

## Unset variables from environment
unset format install_dir

while [[ $# > 0 ]] ;do
   case $1 in 
      --help|-help|help|-h|\?|-\?)  
         --help
         exit
         ;;
      --version|-V|--version-npm|--npm-version|--rev-label|--rev)
         $1
         exit
         ;;
      --install-link|--install|--install-script|--update|--update-script)
         set_action $1
         ;;
      --install-dir=*)
         set_with_warn install_dir "${1##--install-dir=}"
         ;;
      --install=*)  ## same as --install --install-dir=path/to/
         set_action --install
         set_with_warn install_dir "${1##--install=}"
         ;;
      --install-link=*)  ## same as --install-link --install-dir=path/to/
         set_action --install-link
         set_with_warn install_dir "${1##--install-link=}"
         ;;
      --force|-f)
         force=f
         ;;
      --variables|--vars|-v)
         set_action $1
         format=$(echo "$FULL_LIST" | sed -E 's, *([A-Za-z_]+),\1=\$\1\n,g')
         --variables(){ default_action; }
         -v()    { --variables "$@"; }
         --vars(){ --variables "$@"; }
         ;;
      --format=*)       set_with_warn format "${1##--format=}";;
      --format-file=*)  set_with_warn format "$(cat ${1##--format-file=})";;
      --format-from=*)  set_with_warn format "$(cat ${1##--format-from=})";;
      --format-from)    fatalerr "option --format-from requires value";;
      -x|--trace|--xtrace)
         # PS4=$'\e[32m+ '
         set -x;
         ;;
      +x|--no-trace|--no-xtrace)
         set +x;
         ;;
      --debug|-D)  ## Allow echodbg messages, also works if DEBUG is set in environment
         DEBUG=y
         ;;
      --no-debug)  ## Allow echodbg messages, also works if DEBUG is set in environment
         unset DEBUG
         ;;
      --since=*)  ## passed to git rev-list when calculating $count
         var_is_set since  && echowarn "!!! since already set to '$since'. Overriding"
         since="${1##--since=}"
         ;;
      --from=*)  ## passed to git rev-list when calculating $count
         set_with_warn from  "${1##--from=}"
         ;;
      -g|--generate-script|--generate-script=*)
         set_action --generate-script
         script_file="${1##--generate-script=}"
         script_file="${script_file:=/dev/stdout}"
         ;;
      -*|--*) fatalerr "!!! Unknown option $1";;
      *)
         set_with_warn format "$1"
         ;;
   esac
   shift
done

if test ${DEBUG:-empty} != 'empty' ;then
   function echodbg { >/dev/stderr echo $'\e[0;36m'"$@"$'\e[0m'; }
   function DEBUG { "$@" | while read;do echodbg "$REPLY";done ;}
else
   function echodbg { :;}
   function DEBUG { :;}
fi

curl_release(){
   curl 'https://gitlab.com/kyb/git-rev-label/raw/artifacts/master/git-rev-label' -LsSf "$@"
}
########### MAINTENANCE ACTIONS ###########
if var_is_set_not_empty action ;then
   case "$action" in
      --update|--update-script)
         TEMP=`mktemp`
         curl_release -o $TEMP
         chmod +x $TEMP
         if diff -q "${BASH_SOURCE[0]}" $TEMP &>/dev/null ;then
            echomsg "Already up to date."
            rm -f $TEMP
            exit
         else
            exec mv $TEMP $(readlink -f "${BASH_SOURCE[0]}")
         fi
         ;;
      --install-link)
         install_dir=${install_dir:='/usr/local/bin'}
         exec ln -s ${force:+-f} $(readlink -f "${BASH_SOURCE[0]}") "$install_dir/git-rev-label"
         ;;
      --install|--install-script)
         install_dir=${install_dir:='/usr/local/bin'}
         #install_dir=$(eval echo $install_dir)  ## eval is to expand ~, security leak
         touch "$install_dir/git-rev-label" 2>&- || 
            fatalerr "Cannot touch '$install_dir/git-rev-label'. "\
               "Check if directory exists and you have enough access rights!"
         if test -n "${BASH_SOURCE[0]:-}" ;then
            cp "${BASH_SOURCE[0]}" "$install_dir/git-rev-label"
         else
            curl_release > "$install_dir/git-rev-label"
         fi
         chmod +x "$install_dir/git-rev-label"
         exit
         ;;
   esac
fi

## Sanity check
var_is_set install_dir && 
   atalerr "--install_dir should only be used with --install action."


#####################################################
########## SET git rev-label VARIABLES ##############
######### Quintessence (quīnta essentia) ############
format=${format='$refname-c$count-g$short$_DIRTY'}
if test -z "$format" ;then
   echowarn "!!! format is empty."
   exit 0
fi

resolve_dependancies(){ 
   sed -E '
      s,\bSHORT\b,short SHORT,g
      s,\bshort\b,commit short,g
      s,\bLONG\b,long LONG,g
      s,\b_DIRTY\b,_dirty _DIRTY,g
      s,\bDIRTY\b,dirty DIRTY,g
      s,\b_dirty\b,dirty _dirty,g
      s,\brefname\b,branch tag refname,g
   '
}
space_newline(){ sed -E 's, +,\n,g' ;}
variables(){
   commit=$(git rev-parse --short HEAD)
   short=$commit
   SHORT=${short^^}  ## uppercase
   long=$(git rev-parse HEAD)
   LONG=${long^^}
   count=$(git rev-list --count ${since:+--since=$since} --first-parent ${from:+$from..}HEAD)
   COUNT=$(git rev-list --count ${since:+--since=$since}                ${from:+$from..}HEAD)
   dirty=$(git diff-index --quiet HEAD -- && git ls-files --others --error-unmatch . >/dev/null || echo dirty)
   _dirty=${dirty:+-$dirty}  ## Prepends '-' if not empty
   DIRTY=${dirty^^}
   _DIRTY=${_dirty^^}
   branch="$(git rev-parse --abbrev-ref HEAD | sed s,^HEAD$,DETACHED,)"
   tag="$(git tag --list --points-at HEAD | head -1)"
   refname=$(if test "$branch" == DETACHED; then echo "${tag:-DETACHED}"; else echo "$branch";fi;)
}
branch="$(git rev-parse --abbrev-ref HEAD | sed s,^HEAD$,DETACHED,)"
tag="$(git tag --list --points-at HEAD | head -1)"
refname=$(if test "$branch" == DETACHED; then echo "${tag:-DETACHED}"; else echo "$branch";fi;)
get_function_body(){
   for f ;do
      declare -f "$f" | sed '1,2d;$d ; s,^    ,,'
   done
}
requested_variables_to_be_evaluated(){
   ## Calculate only requested variables: parse $format, detect required vars, then calculate required variables.
   requested_variables=$(echo "$format"| perl -ne '$var="[A-Za-z_][A-Za-z0-9_]+"; print "$1$2 " while m,\$(?:($var)|\{($var)\}),g')
echodbg requested_variables=$requested_variables
   if test -z "$requested_variables"
   then return ;fi
   needed_variables=$(grep -Fx -f <(echo $requested_variables|resolve_dependancies|space_newline)  <(echo $FULL_LIST|space_newline))
echodbg needed_variables=$needed_variables
   func_variables_body="$(get_function_body variables)"
   for varname in $needed_variables ;do
      echo "$func_variables_body" |egrep "^\s*$varname="
   done
   echo "export $requested_variables"
}
--generate-script(){
   echo '#!/usr/bin/env bash -euo pipefail'
   echo "## This script was generated with 'git-rev-label --generate-script'"
   echo "## See https://gitlab.com/kyb/git-rev-label"
   requested_variables_to_be_evaluated
   echo "echo ${format@Q} | { $(get_function_body expand_env_vars) ;}"
}

expand_env_vars(){
   perl -pe'$var="[A-Za-z_][A-Za-z0-9_]+"; s,\$(?:($var)|\{($var)\}),$ENV{$1//$2}//$&,eg'  ## see https://stackoverflow.com/questions/57635730/match-substitute-and-expand-shell-variable-using-perl
}

########################################################
########## Handle non-maintenance actions ##############
default_action(){
   eval $(requested_variables_to_be_evaluated)
   echo "$format" | expand_env_vars
}
if ! is_sourced ;then
   ${action:-default_action}  # do action if set and __main__ if not
fi
