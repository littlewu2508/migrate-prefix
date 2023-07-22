#!/bin/sh

die()
{
	local _ret="${2:-1}"
	test "${_PRINT_HELP:-no}" = yes && print_help >&2
	echo "$1" >&2
	exit "${_ret}"
}


begins_with_short_option()
{
	local first_option all_short_options='vh'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

# THE DEFAULTS INITIALIZATION - VERBOSE
VERBOSE=""

print_help()
{
	printf '%s\n' "This script patches a Gentoo Prefix from EPREFIX_OLD to EPREFIX_NEW with the same EPREFIX length"
	printf 'Usage: copy old prefix EPREFIx_OLD to a temp location EROOT, use this scripts to patch files, and move to EPREFIX_NEW'
	printf 'Usage: EROOT=/root/of/prefix/files EPREFIX_OLD=/foo EPREFIX_NEW=/bar %s [-v|--(no-)verbose] [-h|--help]\n' "$0"
	printf '\t%s\n' "-v, --verbose, --no-verbose: verbose when fixing symlinks (off by default)"
	printf '\t%s\n' "-h, --help: Prints help"
}


parse_commandline()
{
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-v|--no-verbose|--verbose)
				VERBOSE="v"
				test "${1:0:5}" = "--no-" && VERBOSE="v"
				;;
			-v*)
				VERBOSE="v"
				_next="${_key##-v}"
				if test -n "$_next" -a "$_next" != "$_key"
				then
					{ begins_with_short_option "$_next" && shift && set -- "-v" "-${_next}" "$@"; } || die "The short option '$_key' can't be decomposed to ${_key:0:2} and -${_key:2}, because ${_key:0:2} doesn't accept value and '-${_key:2:1}' doesn't correspond to a short option."
				fi
				;;
			-h|--help)
				print_help
				exit 0
				;;
			-h*)
				print_help
				exit 0
				;;
			*)
				_PRINT_HELP=yes die "FATAL ERROR: Got an unexpected argument '$1'" 128
				;;
		esac
		shift
	done
}

parse_commandline "$@"

[[ -d "${EROOT}" ]] || die "${EROOT} does not exist or is not a directory!" 78
[[ ${#EPREFIX_OLD} == ${#EPREFIX_NEW} ]] || die "\${EPREFIX_OLD} and \${EPREfIX_NEW} must have same length!" 78

## Change to root directory of prefix being patched
pushd "${EROOT}"

## Change hardcoded prefix in regular files
STEP="patching regular files"
echo "Begin ${STEP}"

find . -type f -exec sed -i -e "s^${EPREFIX_OLD}^${EPREFIX_NEW}^g" "{}" \; || die "Error ${STEP}"

echo "Done ${STEP}"

## Fix broken absolute symlinks
STEP="fixing broken symlinks with absolute path"
echo "Begin ${STEP}"

tmpfile_prefix=tmp_${RANDOM}_
find . -type l > ${tmpfile_prefix}symlinks
find . -type l -exec readlink {} \; > ${tmpfile_prefix}original_link
paste ${tmpfile_prefix}original_link ${tmpfile_prefix}symlinks | sed -n -e "/${EPREFIX_OLD//\//\\\/}/p" > ${tmpfile_prefix}fix_symlink.sh
sed -e "s^${EPREFIX_OLD}^${EPREFIX_NEW}^g" -e "s/^/ln -sf${VERBOSE} /" -i ${tmpfile_prefix}fix_symlink.sh
. ${tmpfile_prefix}fix_symlink.sh || die "Error ${STEP}" # run relink script
rm ${tmpfile_prefix}{original_link,symlinks,fix_symlink.sh}

echo "Done ${STEP}"
