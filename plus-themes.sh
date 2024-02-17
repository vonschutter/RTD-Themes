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
: ${_LOG_DIR:="/var/log/${_TLA:-"rtd"}"} ; mkdir -p "${_LOG_DIR}"

# Determine where to place wallpapers
export _WALLPAPER_DIR="${_WALLPAPER_DIR:-"$(find /opt -name wallpaper)"}"

# Location of base administrative scripts and command-lets to get.
export _git_src_url="https://github.com/${_GIT_PROFILE}/${_TLA^^}-Themes.git"

# Determine log file names for this session if not set
: ${_LOGFILE:="${_LOG_DIR}/$(date +%Y-%m-%d-%H-%M)-$(basename "$0")-setup.log"} ; export _LOGFILE ; touch "${_LOGFILE}"

# Likely dependencies that may be needed for installing various themes:
export _potential_dependencies="7z sassc gettext make git"


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
	local _src_url="https://github.com/${_GIT_PROFILE:-vonschutter}/RTD-Setup/raw/main/core/${1}"
	local script_dir
	script_dir=$( cd "$( dirname "$(readlink -f ${BASH_SOURCE[0]})" )" && pwd )

	if source "${script_dir}/../core/${1}" ; then
		system::log_item "${FUNCNAME[0]}: Using: ${script_dir}/../core/${1}"
	elif source "${script_dir}/../../core/${1}" ; then
		system::log_item "${FUNCNAME[0]}: Using: ${script_dir}/../../core/${1}"
	elif source $(find /opt -name ${1} | grep -v backup) ; then
		system::log_item "${FUNCNAME[0]}: Using: $(find /opt -name ${1} | grep -v backup)"
	elif curl -sL "${_src_url}" -o "./${1}" && source "./${1}" ; then
		system::log_item "${FUNCNAME[0]}: Using: ${_src_url}"
	else
		system::log_item "${1} NOT found!"
		return 1
	fi
	return 0

}


dependency::theme_payload ()
{
	case "$1" in 

	--download | --desktop )
		if echo "$OSTYPE" |grep "linux" ; then
			system::log_item "Linux OS Found: Attempting to get themes for Linux..."
			if ! hash git &>> "${_LOGFILE}" ; then
				system::log_item "git was not found, attmpting to install it..."
				for i in apt yum dnf zypper ; do $i -y install git ; done
			fi
			
			if git clone --depth=1 "${_git_src_url}" /opt/"${_TLA,,}/themes" ; then
				echo "Themes successfully retrieved..."
			else
				system::log_item "Failed to retrieve instructions correctly! "
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

if [[ -z "${RTDFUNCTIONS}" ]] ; then
	system::log_item "Loading RTD functions..."
	dependency::file _rtd_library
	dependency::command_exists ${_potential_dependencies}
else 
	system::log_item "RTD functions already loaded..."
	dependency::command_exists ${_potential_dependencies}
fi


[[ ! -d "/opt/${_TLA}/themes"  ]] || dependency::theme_payload --download |& tee "${_LOGFILE}"


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
unset _tmp


