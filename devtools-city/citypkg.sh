#!/bin/bash

# Avoid any encoding problems
export LANG=C

# check if messages are to be printed using color
unset ALL_OFF BOLD BLUE GREEN RED YELLOW
if [[ -t 2 ]]; then
	# prefer terminal safe colored and bold text when tput is supported
	if tput setaf 0 &>/dev/null; then
		ALL_OFF="$(tput sgr0)"
		BOLD="$(tput bold)"
		BLUE="${BOLD}$(tput setaf 4)"
		GREEN="${BOLD}$(tput setaf 2)"
		RED="${BOLD}$(tput setaf 1)"
		YELLOW="${BOLD}$(tput setaf 3)"
	else
		ALL_OFF="\e[1;0m"
		BOLD="\e[1;1m"
		BLUE="${BOLD}\e[1;34m"
		GREEN="${BOLD}\e[1;32m"
		RED="${BOLD}\e[1;31m"
		YELLOW="${BOLD}\e[1;33m"
	fi
fi
readonly ALL_OFF BOLD BLUE GREEN RED YELLOW

plain() {
	local mesg=$1; shift
	printf "${BOLD}    ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg() {
	local mesg=$1; shift
	printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg2() {
	local mesg=$1; shift
	printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

warning() {
	local mesg=$1; shift
	printf "${YELLOW}==> WARNING:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

error() {
	local mesg=$1; shift
	printf "${RED}==> ERROR:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

stat_busy() {
	local mesg=$1; shift
	printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}...${ALL_OFF}" >&2
}

stat_done() {
	printf "${BOLD}done${ALL_OFF}\n" >&2
}

setup_workdir() {
	[[ -z $WORKDIR ]] && WORKDIR=$(mktemp -d --tmpdir "${0##*/}.XXXXXXXXXX")
}

cleanup() {
	trap - EXIT INT QUIT TERM HUP

	[[ -n $WORKDIR ]] && rm -rf "$WORKDIR"
	[[ $1 ]] && exit $1
}

abort() {
	msg 'Aborting...'
	cleanup 0
}

die() {
	error "$*"
	cleanup 1
}

trap abort INT QUIT TERM HUP
trap 'cleanup 0' EXIT

##
#  usage : in_array( $needle, $haystack )
# return : 0 - found
#          1 - not found
##
in_array() {
	local needle=$1; shift
	local item
	for item in "$@"; do
		[[ $item = $needle ]] && return 0 # Found
	done
	return 1 # Not Found
}

##
#  usage : get_full_version( [$pkgname] )
# return : full version spec, including epoch (if necessary), pkgver, pkgrel
##
get_full_version() {
	# set defaults if they weren't specified in buildfile
	pkgbase=${pkgbase:-${pkgname[0]}}
	epoch=${epoch:-0}
	if [[ -z $1 ]]; then
		if [[ $epoch ]] && (( ! $epoch )); then
			echo $pkgver-$pkgrel
		else
			echo $epoch:$pkgver-$pkgrel
		fi
	else
		for i in pkgver pkgrel epoch; do
			local indirect="${i}_override"
			eval $(declare -f package_$1 | sed -n "s/\(^[[:space:]]*$i=\)/${i}_override=/p")
			[[ -z ${!indirect} ]] && eval ${indirect}=\"${!i}\"
		done
		if (( ! $epoch_override )); then
			echo $pkgver_override-$pkgrel_override
		else
			echo $epoch_override:$pkgver_override-$pkgrel_override
		fi
	fi
}


getpkgfile() {
	case $# in
		0)
			error 'No canonical package found!'
			return 1
			;;
		[!1])
			error 'Failed to canonicalize package name -- multiple packages found:'
			msg2 '%s' "$@"
			return 1
			;;
	esac

	echo "$1"
}

# Source makepkg.conf; fail if it is not found
if [[ -r '/etc/makepkg.conf' ]]; then
	source '/etc/makepkg.conf'
else
	die '/etc/makepkg.conf not found!'
fi

# Source user-specific makepkg.conf overrides
if [[ -r ~/.makepkg.conf ]]; then
	. ~/.makepkg.conf
fi

cmd=${0##*/}

if [[ ! -f PKGBUILD ]]; then
	die 'No PKGBUILD file'
fi

. PKGBUILD
pkgbase=${pkgbase:-$pkgname}

case "$cmd" in
	commitpkg)
		if (( $# == 0 )); then
			die 'usage: commitpkg <reponame> [-f] [-s server] [-l limit] [-a arch] [commit message]'
		fi
		repo="$1"
		shift
		;;
	*pkg)
		repo="${cmd%pkg}"
		;;
	*)
		die 'usage: commitpkg <reponame> [-f] [-s server] [-l limit] [-a arch] [commit message]'
		;;
esac

# find files which should be under source control
needsversioning=()
for s in "${source[@]}"; do
	[[ $s != *://* ]] && needsversioning+=("$s")
done
for i in 'changelog' 'install'; do
	while read -r file; do
		# evaluate any bash variables used
		eval file=\"$(sed 's/^\(['\''"]\)\(.*\)\1$/\2/' <<< "$file")\"
		needsversioning+=("$file")
	done < <(sed -n "s/^[[:space:]]*$i=//p" PKGBUILD)
done

# assert that they really are controlled by GIT
#if (( ${#needsversioning[*]} )); then
#	for _needsversioning in "${needsversioning[@]}"; do
#		echo ${_needsversioning};
#		if ! git ls-files --error-unmatch "${_needsversioning}">/dev/null 2>&1; then
#			unversioned+=("${_needsversioning}")
#		fi
#	done
#	(( ${#unversioned[*]} )) && die "${unversioned[@]} is not under version control"
#fi

rsyncopts=(-e ssh -p --chmod=ug=rw,o=r -c -h -L --progress --partial -y)
archreleaseopts=()
while getopts ':l:a:s:f' flag; do
	case $flag in
		f) archreleaseopts+=('-f') ;;
		s) server=$OPTARG ;;
		l) rsyncopts+=("--bwlimit=$OPTARG") ;;
		a) commit_arch=$OPTARG ;;
		:) die "Option requires an argument -- '$OPTARG'" ;;
		\?) die "Invalid option -- '$OPTARG'" ;;
	esac
done
shift $(( OPTIND - 1 ))

# check packages have the packager field set
for _arch in ${arch[@]}; do
	if [[ -n $commit_arch && ${_arch} != "$commit_arch" ]]; then
		continue
	fi
	for _pkgname in ${pkgname[@]}; do
		fullver=$(get_full_version $_pkgname)

		if pkgfile=$(shopt -s nullglob;
				getpkgfile "${PKGDEST+$PKGDEST/}$_pkgname-$fullver-${_arch}".pkg.tar.?z); then
			if grep -q "packager = Unknown Packager" <(bsdtar -xOqf $pkgfile .PKGINFO); then
				die "PACKAGER was not set when building package"
			fi
		fi
	done
done

msg "Create source info..."
makepkg --printsrcinfo > .SRCINFO || die
msg "Create source package..."
makepkg --source -f || die
msg "Add source files to repository..."
git add PKGBUILD .SRCINFO ${needsversioning[@]} || die

if [[ -z $server ]]; then
	case "$repo" in
		city|ayatana)
			server='pkgbuild.com' ;;
		*)
			server='pkgbuild.com'
			msg "Non-standard repository $repo in use, defaulting to server $server" ;;
	esac
fi

if [[ -n $(git diff --staged) ]]; then
	msgtemplate="upgpkg: $pkgbase $(get_full_version)"$'\n\n'
	if [[ -n $1 ]]; then
		msg 'Commit changes to master'
		git commit -a -q -m "${msgtemplate}${1}" || die
	else
		msgfile="$(mktemp)"
		echo "$msgtemplate" > "$msgfile"
		if [[ -n $SVN_EDITOR ]]; then
			$SVN_EDITOR "$msgfile"
		elif [[ -n $VISUAL ]]; then
			$VISUAL "$msgfile"
		elif [[ -n $EDITOR ]]; then
			$EDITOR "$msgfile"
		else
			nano "$msgfile"
		fi
		[[ -s $msgfile ]] || die
		msg 'Committing changes to master'
		git commit -a -q -F "$msgfile" || die
		unlink "$msgfile"
	fi
	msg 'Updating remote repository'
	git push
fi

declare -a uploads
declare -a commit_arches
declare -a skip_arches

if ! srcfile=$(shopt -s nullglob;
		getpkgfile "${SRCDEST+$SRCDEST/}${pkgbase:-${pkgname[0]}}-$fullver".src.tar.gz); then
	die "Failed to locate source file $_pkgname-$fullver"
fi
uploads+=("$srcfile")

for _arch in ${arch[@]}; do
	if [[ -n $commit_arch && ${_arch} != "$commit_arch" ]]; then
		skip_arches+=($_arch)
		continue
	fi

	for _pkgname in ${pkgname[@]}; do
		fullver=$(get_full_version $_pkgname)

		if ! pkgfile=$(shopt -s nullglob;
				getpkgfile "${PKGDEST+$PKGDEST/}$_pkgname-$fullver-${_arch}".pkg.tar.?z); then
			warning "Skipping $_pkgname-$fullver-$_arch: failed to locate package file"
			skip_arches+=($_arch)
			continue 2
		fi
		uploads+=("$pkgfile")

		sigfile="${pkgfile}.sig"
		if [[ ! -f $sigfile ]]; then
			msg "Signing package ${pkgfile}..."
			if [[ -n $GPGKEY ]]; then
				SIGNWITHKEY="-u ${GPGKEY}"
			fi
			gpg --detach-sign --use-agent --no-armor ${SIGNWITHKEY} "${pkgfile}" || die
		fi
		if ! gpg --verify "$sigfile" >/dev/null 2>&1; then
			die "Signature ${pkgfile}.sig is incorrect!"
		fi
		uploads+=("$sigfile")
	done
done

for _arch in ${arch[@]}; do
	if ! in_array $_arch ${skip_arches[@]}; then
		commit_arches+=($_arch)
	fi
done

if [[ ${#uploads[*]} -gt 0 ]]; then
	new_uploads=()

	# convert to absolute paths so rsync can work with colons (epoch)
	while read -r -d '' upload; do
		new_uploads+=("$upload")
	done < <(realpath -z "${uploads[@]}")

	uploads=("${new_uploads[@]}")
	unset new_uploads
	msg 'Uploading all package and signature files'
	rsync "${rsyncopts[@]}" "${uploads[@]}" "$server:staging/$repo/" || die
fi
