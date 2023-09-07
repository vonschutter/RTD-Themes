#!/bin/bash
PUBLICATION="${_TLA} Simple Global Theme Install"
VERSION="1.00"
#
#::             Linux Theme Installer Script
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::// Linux //::::
#:: Author(s):   	SLS
#:: Version 1.00
#::
#::
#::	Purpose: The purpose of this script is to install all relevant themes in th folders ico, kde, and gtk
#::		 found in the current dicectory. It will extract the 7z compressed files, and look for install.sh in
#::		 folder and run it.
#::
#::	Dependencies: - There may be dependencies like make and other development utilities.
#::		      - It is also assumed that there is an "install.sh" script in the root of each compressed archive.
#::			This script may be supplied by the maintainer of the theme or us/you. It shall, by default,
#::			install a sensible set of theme files (icons, themes, colors etc.).
#::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#::::::::::::::                                          ::::::::::::::::::::::
#::::::::::::::          Script Settings                 ::::::::::::::::::::::
#::::::::::::::                                          ::::::::::::::::::::::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::


# Ensure administrative privileges.
[ "$UID" -eq 0 ] || echo -e "This script needs administrative access..." 
[ "$UID" -eq 0 ] || exec sudo -E bash "$0" "$@"

# Put a convenient link to the logs where logs are normally found...
# capture the 3 first letters as org TLA (Three Letter Acronym)
: "${_my_scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"}"
: "${_tmp="$( mktemp -d )"}"
: "${_GIT_PROFILE:-"vonschutter"}"

# Determine a reasonable location to place logs:
export _LOG_DIR="/var/log/${_TLA:-"rtd"}" ; mkdir -p "${_LOG_DIR}"

# Determine where to place wallpapers
export _WALLPAPER_DIR="${_WALLPAPER_DIR:-"$(find /opt -name wallpaper)"}"

# Location of base administrative scripts and command-lets to get.
export _git_src_url="https://github.com/${_GIT_PROFILE}/${_TLA^^}-Setup.git"

# Determine log file names for this session
_LOGFILE="${_LOG_DIR}/$(date +%Y-%m-%d-%H-%M)-$(basename "$0")-setup.log" ; export _LOGFILE

# Likely dependencies that may be needed for installing various themes:
export _potential_dependencies="p7zip-full p7zip p7zip-plugins sassc gettext make git"


#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#::::::::::::::                                          ::::::::::::::::::::::
#::::::::::::::          Script Functions                ::::::::::::::::::::::
#::::::::::::::                                          ::::::::::::::::::::::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::





theme::help ()
{
	clear
	echo "	${PUBLICATION} ${VERSION}: ${FUNCNAME[0]}
	------------------------------------------------------------
	🔧           Linux Desktop Theme Install Script           🔧
	------------------------------------------------------------
	This script is used to install themes on a linux system. It assumes that themes
	are placed in sub folders named gtk, kde, ico, and fon, directly in same folder as
	this script itself. In each of these folders idividual themes for icons, gnome,
	plasma, and fonts are compressed in the 7z format. This format often results in
	half the files sizes compared to the zip format. Further, in each of these compressed
	archives a script called install.sh is expected. The install.sh file should do the job of
	copying the contents to the appropriate location.

	Syntax:
	${0} [ --gtk | --kde | --font | --icon | --bash | --all | --help ]

	Where:
	--gtk	Install all Gnome themes
	--kde 	Install all KDE Plasma themes
	--fonts	Install all additional fonts
	--icons Install all additional icon themes
	--bash  Install bash terminal theme with starship
	--all	Install everything
	--help	Display this help message

	If nothing is specified the script will try to detect the desktop session and
	install the appropriate themes.

	"
}


theme::add_global ()
{
	case "${1}" in
	--bash | --font | --gtk | --icon | --kde )
		pushd "${_my_scriptdir}/${1/--/}" || return 1
		for i in *.7z ; do
			7z x "$i" -aoa -o"${_tmp}"
			pushd "${_tmp}/${i::-3}"  || return 1
			bash ./install.sh || ( echo "An error occurred while trying to run the install.sh" ; return 1 )
			popd || return 1
		done
		popd || return 1
	;;
	--wallpaper )
		chmod 555 -R "${_my_scriptdir}/${1/--/}"
		if  pgrep -f "gnome-shell" &>/dev/null ; then 
			oem::register_wallpapers_for_gnome "${_my_scriptdir}/${1/--/}" || return 1
		elif  pgrep -f "plasmashell" &>/dev/null ; then
			system::log_item "Registering wallpapers in: ${_XDG_WALLPAPER_DIR}/"
			ln -fs "${_my_scriptdir}/${1/--/}"/* "${_XDG_WALLPAPER_DIR}"/ || return 1
		else 
			system::log_item "NOT Sure what DE, registering wallpapers in: ${_XDG_WALLPAPER_DIR}/ and /usr/share/backgrounds/"
			ln -fs "${_my_scriptdir}/${1/--/}"/* "${_XDG_WALLPAPER_DIR}"/ || return 1
			ln -fs "${_my_scriptdir}/${1/--/}"/* /usr/share/backgrounds/ || return 1
		fi
	;;
	* )
		echo "Neither GTK or KDE themes were requested"
	;;
	esac
}



dependency::file ()
{
	_src_url="https://github.com/${_GIT_PROFILE:-vonschutter}/RTD-Setup/raw/main/core/${1}"

	dependency::search_local ()
	{
		echo "${FUNCNAME[0]}: Searching for ${1} ..."

		for i in "./${1}" \
		"${0%/*}/../core/${1}" \
		"${0%/*}/../../core/${1}" \
		"../core/${1}" \
		"../../core/${1}" \
		"$(find /opt -name "${1}" |grep -v bakup )" ; do 
			tee "${FUNCNAME[0]}: Searching for ${i} ..." >>"${_LOGFILE}"
			if [[ -e "${i}" ]] ; then 
				tee "${FUNCNAME[0]}: Found ${i}" >>"${_LOGFILE}"
				source "${i}" ""
				return 0
			fi
		done	
	}

	if dependency::search_local "${1}" ; then
		return 0
	else
		if wget "${_src_url}" &>/dev/null ; then
			source ./"${1}"
			echo "${FUNCNAME[0]} Using: ${_src_url}"
		else 
			echo "${FUNCNAME[0]} Failed to find  ${1} "
			exit 1
		fi
	fi 

}


dependency::theme_payload ()
{
	case "$1" in 

	--download | --desktop )
		# shellcheck disable=SC2317
		if echo "$OSTYPE" |grep "linux" ; then
			system::log_item "Linux OS Found: Attempting to get instructions for Linux..."
			system::log_item "executing $0"
			if ! hash git &>> "${_LOGFILE}" ; then
				system::log_item "git was not found, attmpting to install it..."
				for i in apt yum dnf zypper ; do $i -y install git | tee "${_LOGFILE}" ; done
			fi
			
			if ! git clone --depth=1 "${_git_src_url}" /opt/"${_TLA,,}".tmp | tee "${_LOGFILE}" ;
			then
				echo "Instructions successfully retrieved..."
				if [[ -d /opt/${_TLA,,}  ]] ; then
					mv /opt/"${_TLA,,}" "${_BackupFolderName:=/opt/${_TLA,,}.$(date +%Y-%m-%d-%H-%M-%S-%s).bakup}"
					zip -m -r -5 "${_BackupFolderName}".zip  "${_BackupFolderName}"
					rm -r "${_BackupFolderName}"
				fi
				mv /opt/"${_TLA,,}".tmp /opt/"${_TLA,,}" ; rm -rf /opt/"${_TLA,,}"/.git
				source "/opt/${_TLA,,}/core/_rtd_library"
				oem::register_all_tools
				ln -s -f "${_LOG_DIR}" -T "${_OEM_DIR}"/log
				bash "${_OEM_DIR}"/core/rtd-oem-linux-config.sh "${*}"
			else
				system::log_item "Failed to retrieve instructions correctly! "
				system::log_item "Suggestion: check write permission in /opt or internet connectivity."
				return 1
			fi
		elif [[ "$OSTYPE" == "darwin"* ]]; then
			echo "Mac OSX is currently not supported..."
		elif [[ "$OSTYPE" == "cygwin" ]]; then
			echo "CYGWIN is currently unsupported..."
		elif [[ "$OSTYPE" == "msys" ]]; then
			echo "Lightweight shell is currently unsupported... "
		elif [[ "$OSTYPE" == "freebsd"* ]]; then
			echo "Free BSD is currently unsupported... "
		else
			echo "This system is Unknown to this script"
		fi
	;;
	* ) write_error "No action requested..."
	esac
}



#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#::::::::::::::                                          ::::::::::::::::::::::
#::::::::::::::          Execute tasks                   ::::::::::::::::::::::
#::::::::::::::                                          ::::::::::::::::::::::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

dependency::file _rtd_library && for i in ${_potential_dependencies} ; do check_dependencies  "${i}" ; done
[[ -d "/opt/${_TLA}/themes"  ]] || dependency::theme_payload --download

case $1 in
	--gtk | --gnome )
		system::log_item "Foced install of GTK themes..."
		theme::add_global --gtk
	;;
	--kde | --plasma )
		system::log_item "Foced install of KDE themes..."
		theme::add_global --kde
	;;
	--all )
		echo "Foced install of ALL themes..."
		theme::add_global --kde
		theme::add_global --gtk
		theme::add_global --icon
		theme::add_global --font
		theme::add_global --bash
	;;
	--icons | --icon)
		system::log_item "Installing icons only..."
		theme::add_global --icon
	;;
	--fonts | --font )
		system::log_item "Installing fonts only"
		theme::add_global --font
	;;
	--bash | --term | --terminal )
		system::log_item "Installing bash theme only"
		theme::add_global --bash
	;;
	--wallpaper | --backgrounds | --images )
		system::log_item "Installing Wallpapers only"
		theme::add_global --wallpaper
	;;
	--help )
		theme::help
	;;
	* )
		system::log_item "No preference stated. Autodetecting themes for current environment..."
		if  pgrep -f "plasmashell" ; then
			system::log_item "Found plasmashell; installing kde themes, icons, fonts, bash theme, and wallpapers..."
			theme::add_global --kde
			theme::add_global --icon
			theme::add_global --font
			theme::add_global --bash
			theme::add_global --wallpaper
		elif  pgrep -f "gnome-shell"; then
			system::log_item "Found gnome-shell; installing gnome themes, icons, fonts, bash theme, and wallpapers..."
			theme::add_global --gtk
			theme::add_global --icon
			theme::add_global --font
			theme::add_global --bash
			theme::add_global --wallpaper
		else
			system::log_item "Neither plasma or gnome was found! Only installing Icons, wallpapers and fonts."
			theme::add_global --icon
			theme::add_global --font
			theme::add_global --wallpaper
		fi
	;;
esac


#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#::::::::::::::                                          ::::::::::::::::::::::
#::::::::::::::          Finalize.....                   ::::::::::::::::::::::
#::::::::::::::                                          ::::::::::::::::::::::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
unset _my_scriptdir
unset _potential_dependencies
exit

