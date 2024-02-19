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
: "${_GIT_PROFILE:-"vonschutter"}"

# Determine a reasonable location to place logs:
: ${_LOG_DIR:="/var/log/${_TLA:-"rtd"}"} ; mkdir -p "${_LOG_DIR}"

# Determine where to place wallpapers
export _WALLPAPER_DIR="$(find /opt/${_TLA:-rtd}/modules -name wallpaper)"

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
	This script is used to install themes on a Linux system. It assumes that themes
	are placed in sub folders named wallpaper, gtk, kde, ico, and fon, directly in same folder as
	this script itself. In each of these folders individual themes for icons, gnome,
	plasma, and fonts are compressed in the 7z format. This format often results in
	half the files sizes compared to the zip format. Further, in each of these compressed
	archives a script called install.sh is expected. The install.sh file should do the job of
	copying the contents to the appropriate location.

	Syntax:
	${0} [ --wallpaper | --gtk | --kde | --font | --icon | --bash | --all | --help ]

	Where:
	--wallpaper    Install wallpapers
	--gtk          Install all Gnome themes
	--kde          Install all KDE Plasma themes
	--fonts        Install all additional fonts
	--icons        Install all additional icon themes
	--bash         Install bash terminal theme with starship
	--all          Install everything
	--help         Display this help message

	If nothing is specified the script will try to detect the desktop session and
	install the appropriate themes.

	"
}


theme::add_global ()
{
	case "${1}" in
		--bash | --font | --gtk | --icon | --kde )
			pushd "${_my_scriptdir}/${1/--/}" || { write_error "${1/--/} not found where expected"; return 1; }
			local _tmp _archives
			_tmp="$( mktemp -d )"
			readarray -t _archives < <(find . -name '*.7z' -o -name '*.7z.001')

			for arch in "${_archives[@]}"; do
				# Extract only if it's a single .7z file or the first part of a multi-part archive
				write_status "Processing file: $arch"
				7z x "$arch" -aoa -o"${_tmp}"

				# Remove leading './' if present due to `find` command usage
				arch=${arch#./}

				# set extracted folder name...
				if [[ "$arch" =~ \.7z\.001$ ]]; then
					dir_name="${arch%.7z.001}"
				elif [[ "$arch" =~ \.7z$ ]]; then
					dir_name="${arch%.7z}"
				else
					write_error "No matching extension for $arch"
					continue
				fi

				# Enter and run the included installer
				pushd "${_tmp}/${dir_name}" || { write_error "A problem was encountered when attempting to access the directory ${_tmp}/${dir_name}"; return 1; }

				if [[ -f ./run.sh ]]; then
					bash ./run.sh || { write_error "An error occurred while trying to run the run.sh"; return 1; }
				elif [[ -f ./install.sh ]]; then
					bash ./install.sh || { write_error "An error occurred while trying to run the install.sh"; return 1; }
				fi

				popd || { write_error "Failure to pop from directory ${dir_name}"; return 1; }
			done

			popd || { write_error "Failure to pop from directory ${1/--/}"; return 1; }
		;;
		--wallpaper )
			chmod 555 -R "${_my_scriptdir}/${1/--/}"
			if  pgrep -f "gnome-shell" &>/dev/null ; then
				oem::register_wallpapers_for_gnome "${_my_scriptdir}/${1/--/}/wallpaper" || return 1
			elif  pgrep -f "plasmashell" &>/dev/null ; then
				theme::log_item "Registering wallpapers in: ${_XDG_WALLPAPER_DIR}/"
				ln -fs "${_my_scriptdir}/${1/--/}"/* "${_XDG_WALLPAPER_DIR}"/ || return 1
			else
				theme::log_item "NOT Sure what DE, registering wallpapers in: ${_XDG_WALLPAPER_DIR}/ and /usr/share/backgrounds/"
				ln -fs "${_my_scriptdir}/${1/--/}"/* "${_XDG_WALLPAPER_DIR}"/ || return 1
				ln -fs "${_my_scriptdir}/${1/--/}"/* /usr/share/backgrounds/ || return 1
			fi
		;;
		* )
			write_warning "Neither GTK or KDE themes were requested"
		;;
	esac
}


dependency::theme_payload ()
{
	case "$1" in 

	--download | --desktop )
		if echo "$OSTYPE" |grep "linux" ; then
			theme::log_item "Linux OS Found: Attempting to get themes for Linux..."
			if ! hash git &>> "${_LOGFILE}" ; then
				theme::log_item "git was not found, attempting to install it..."
				for i in apt yum dnf zypper ; do $i -y install git ; done
			fi
			
			if git clone --depth=1 "${_git_src_url}" /opt/"${_TLA,,}/themes" ; then
				echo "Themes successfully retrieved..."
			else
				theme::log_item "Failed to retrieve instructions correctly! "
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


theme::register_wallpapers_for_gnome ()
{
	# Validate the input directory
	local _wallpaper_dir="${1:-"${_WALLPAPER_DIR}"}"
	if [[ ! -d "$_wallpaper_dir" ]]; then
		echo "Error: Directory '$_wallpaper_dir' does not exist."
		return 1
	fi

	local xml_file="oem-backgrounds.xml"
	local dest_dir="/usr/local/share/gnome-background-properties"
	local dest_file="${dest_dir}/${xml_file}"

	# Start with the XML header
	cat > "$xml_file" <<-EOF
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
	<wallpapers>
	EOF

	# Safely iterate over .jpg and .png files
	shopt -s nullglob
	for i in "$_wallpaper_dir"/*.jpg "$_wallpaper_dir"/*.png; do
		cat >> "$xml_file" <<-EOF
	<wallpaper>
	    <name>$(basename "$i")</name>
	    <filename>$i</filename>
	    <options>stretched</options>
	    <pcolor>#8f4a1c</pcolor>
	    <scolor>#8f4a1c</scolor>
	    <shade_type>solid</shade_type>
	</wallpaper>
	EOF
	done
	shopt -u nullglob

	# Finish with the XML footer
	echo "</wallpapers>" >> "$xml_file"

	# Ensure the destination directory exists
	mkdir -p "$dest_dir"
	mv "$xml_file" "$dest_file"

	echo "Wallpapers registered successfully at $dest_file"
}



set_colors ()
{
  	local ecode="\033["

	yellow="${ecode}1;33m"
	darkyellow="${ecode}0;33m"
	red="${ecode}1;31m"
	darkred="${ecode}0;31m"
	endcolor="${ecode}0m"
	green="${ecode}1;32m"
	darkgreen="${ecode}1;32m"
	blue="${ecode}1;34m"
	darkblue="${ecode}0;34m"
	cyan="${ecode}0;36"
	darkcyan="${ecode}0;36"
	gray="${ecode}0;37"
	purple="${ecode}1;35"
	darkpurple="${ecode}0;35"
}





write_host ()
{
	_option=$1

	case ${_option} in
		--yellow ) color="$(tput bold; tput setaf 3)" ;;
		--darkyellow ) color="$(tput dim; tput setaf 3)" ;;
		--red ) color="$(tput bold; tput setaf 1)" ;;
		--darkred ) color="$(tput setaf 3)" ;;
		--endcolor ) color="$(tput sgr0)" ;;
		--green ) color="$(tput bold; tput setaf 2)" ;;
		--darkgreen ) color="$(tput dim; tput setaf 2)" ;;
		--blue ) color="$(tput bold; tput setaf 4)" ;;
		--darkblue ) color="$(tput dim; tput setaf 4)" ;;
		--cyan ) color="$(tput bold; tput setaf 6)" ;;
		--darkcyan ) color="$(tput dim; tput setaf 6)" ;;
		--gray ) color="$(tput dim; tput setaf 7)" ;;
		--purple ) color="$(tput bold; tput setaf 5)" ;;
		--darkpurple ) color="$(tput dim; tput setaf 5)" ;;
		*) local _text="$1" ;;
	esac
	[[ -z "${_text}" ]] && local _text="${color} 💻 $2 $(tput sgr0)"
	echo -e "${_text} "

	# Tell the logging function to log the message requested...
	theme::log_item "🧩 💻 ${FUNCNAME[1]}: ${_text}"

}



write_error ()
{
	local text=$1

	if [[ "${TERMUITXT}" == "nocolor" ]]; then
		if [[ -n "${text}" ]]; then
			echo "🧩 💥 ${FUNCNAME[1]}: ${text}"
		fi
	else
		if [[ -n "${text}" ]]; then
			echo -e "$(tput bold; tput setaf 1)🧩 💥 ${FUNCNAME[1]}: ${text}${endcolor}"
		fi
	fi

	# Tell the logging function to log the message requested...
	[ -n "${text}" ] && theme::log_item "🧩 💥 ${FUNCNAME[1]}: ${text}"

}


write_warning ()
{
	local text=$1

	if [[ "${TERMUITXT}" == "nocolor" ]]; then
		[ -n "${text}" ] && echo "🧩 ⚠ ${FUNCNAME[1]}: ${text}"
	else
		[ -n "${text}" ] && echo -e "${yellow}🧩 ⚠ ${FUNCNAME[1]}: ${text}${endcolor}"
	fi

	# Tell the logging function to log the message requested...
	[ -n "${text}" ] && theme::log_item "🧩 ⚠ ${FUNCNAME[1]}: ${text}"
	
}


write_status ()
{
	local text=$1

	if [[ "${TERMUITXT}" == "nocolor" ]] ; then
		[ -n "${text}" ] && echo "🧩 ✓ ${FUNCNAME[1]}: ${text}"
	else
		[ -n "${text}" ] && echo -e "${green}🧩 ✓ ${FUNCNAME[1]}: ${text}${endcolor}"
	fi

	# Tell the logging function to log the message requested...
	[ -n "${text}" ] && theme::log_item "🧩 ✓ ${FUNCNAME[1]}: ${text}"
	
}


write_information ()
{
	local text=$1

	if [[ "${TERMUITXT}" == "nocolor" ]] ; then
		[ -n "${text}" ] && echo -e "🧩 🛈 ${FUNCNAME[1]}: ${text}"
	else
		[ -n "${text}" ] && echo -e "${blue}🧩 🛈 ${FUNCNAME[1]}: ${text}${endcolor}"
	fi

	# Tell the logging function to log the message requested...
	theme::log_item "🧩 🛈 ${FUNCNAME[1]}: ${text}"
	
}




theme::log_item () {
	if [[ -z $_LOGFILE ]]; then
		# If log file not set globally, set it to defaults for this function a.k.a. script name
		local date
		local logfile
		local scriptname

		scriptname=$(basename "${BASH_SOURCE[0]}")
		tla=${scriptname:0:3}
		touch "$logfile"
		date="$(date '+%Y/%m/%d %H:%M')"

		if [[ $EUID -ne 0 ]]; then
			local log_dir="${HOME}/.config/rtd/logs"
		else
			local log_dir=${_LOG_DIR:-"/var/log/${tla,,}"}
		fi

		if ! mkdir -p "$log_dir"; then
			printf "Error: could not create log directory %s\n" "$log_dir" >&2
			return 1
		fi

		local logfile="${log_dir}/${scriptname}.log"
	else 
		local logfile="${_LOGFILE}"
	fi


	# Format the log item based on the calling function for clear reading
	local log_prefix="${date}  ---"
	local log_type=""
	local log_message=""

	case "${FUNCNAME[1]}" in
		write_error)
			log_type="ERR!"
			log_message="$*"
		;;
		write_warning)
			log_type="WARN"
			log_message="$*"
		;;
		write_information)
			log_type="INFO"
			log_message="$*"
		;;
		write_host)
			log_type="HOST"
			log_message="$*"
		;;
		write_status)
			log_type="STAT"
			log_message="$*"
		;;
		*)
			log_type="LOGD"
			log_message="${FUNCNAME[1]}: $*"
		;;
	esac

	echo "${log_prefix} ${log_type} : ${log_message}" >> "$logfile"
}




#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#::::::::::::::                                          ::::::::::::::::::::::
#::::::::::::::          Execute tasks                   ::::::::::::::::::::::
#::::::::::::::                                          ::::::::::::::::::::::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

set_colors
[[ ! -d "/opt/${_TLA}/themes"  ]] || dependency::theme_payload --download |& tee "${_LOGFILE}"


case $1 in
	--gtk | --gnome )
		theme::log_item "Foced install of GTK themes..."
		theme::add_global --gtk
	;;
	--kde | --plasma )
		theme::log_item "Foced install of KDE themes..."
		theme::add_global --kde
	;;
	--all )
		write_information "Foced install of ALL themes..."
		theme::add_global --kde
		theme::add_global --gtk
		theme::add_global --icon
		theme::add_global --font
		theme::add_global --bash
	;;
	--icons | --icon)
		theme::log_item "Installing icons only..."
		theme::add_global --icon
	;;
	--fonts | --font )
		theme::log_item "Installing fonts only"
		theme::add_global --font
	;;
	--bash | --term | --terminal )
		theme::log_item "Installing bash theme only"
		theme::add_global --bash
	;;
	--wallpaper | --backgrounds | --images )
		theme::log_item "Installing Wallpapers only"
		theme::add_global --wallpaper
	;;
	--help )
		theme::help
	;;
	* )
		theme::log_item "No preference stated. Autodetecting themes for current environment..."
		if  pgrep -f "plasmashell" ; then
			theme::log_item "Found plasmashell; installing kde themes, icons, fonts, bash theme, and wallpapers..."
			theme::add_global --kde
			theme::add_global --icon
			theme::add_global --font
			theme::add_global --bash
			theme::add_global --wallpaper
		elif  pgrep -f "gnome-shell"; then
			theme::log_item "Found gnome-shell; installing gnome themes, icons, fonts, bash theme, and wallpapers..."
			theme::add_global --gtk
			theme::add_global --icon
			theme::add_global --font
			theme::add_global --bash
			theme::add_global --wallpaper
		else
			theme::log_item "Neither plasma or gnome was found! Only installing Icons, wallpapers and fonts."
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


