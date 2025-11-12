#!/bin/bash
PUBLICATION=$(basename "$0" .sh | cut -c 1-3 | tr '[:lower:]' '[:upper:]'); PUBLICATION="${PUBLICATION} Simple Global Theme Install"
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
[ "$UID" -eq 0 ] || { echo -e "This script needs administrative access..." ; exec sudo -E bash "$0" "$@" ; }

# Set key variables with defaults for when they are not defined in the environment
: "${_my_scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"}"
: "${_GIT_PROFILE:="vonschutter"}"
: "${_scriptname="$( basename "${BASH_SOURCE[0]}" )"}"

# Override _TLA and _tla (comment out the 2 lines below to auto assign _TLA and _tla from script name)
_TLA=RTD
_tla=rtd

if [[ -z $_TLA ]] ; then 
: "${_TLA:="$(basename "$0" .sh | cut -c 1-3 | tr '[:lower:]' '[:upper:]'); _TLA=${_TLA})"}"
: "${_tla:="$(basename "$0" .sh | cut -c 1-3 | tr '[:upper:]' '[:lower:]')"}"
fi

# Determine a reasonable location to place logs:
: "${_LOG_DIR:="/var/log/${_tla:-"rtd"}"}" ; mkdir -p "${_LOG_DIR}"

# Location of theme wallpapers
_WALLPAPER_DIR="/opt/${_tla:-rtd}/themes/wallpaper"
: "${_XDG_WALLPAPER_DIR:="/usr/share/wallpapers"}"

# Location of base administrative scripts and command-lets to get.
export _git_src_url="https://github.com/${_GIT_PROFILE}/${_TLA^^}-Themes.git"

# Determine log file names for this session if not set
: "${_LOGFILE:="${_LOG_DIR}/$(date +%Y-%m-%d-%H-%M)-$(basename "$0")-setup.log"}" ; export _LOGFILE ; touch "${_LOGFILE}"

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



theme::run_command_in_gnome_user_session () {
	sudo -H -u "$SUDO_USER" DISPLAY="$DISPLAY" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$SUDO_USER")/bus" bash -c "$*"
}


theme::add_global ()
{
	case "${1}" in
			--bash | --font | --gtk | --icon | --kde )
				local _tmp _archives dir_name
				if ! (
					cd "${_my_scriptdir}/${1/--/}" || { write_error "${1/--/} not found where expected"; exit 1; }
					write_status "Entering ${_my_scriptdir}/${1/--/} directory"

					if ! _tmp="$(mktemp -d)"; then
						write_error "Unable to create temporary directory for ${1/--/} processing"
						exit 1
					fi
					trap '[[ -d "$_tmp" ]] && rm -rf "$_tmp"' EXIT

					readarray -t _archives < <(find . -name '*.7z' -o -name '*.7z.001')
					write_status "Found ${#_archives[@]} archives in ${1/--/} folder"

					for arch in "${_archives[@]}"; do
						# Extract only if it's a single .7z file or the first part of a multi-part archive
						write_status "Processing package archive: $arch"
						7z x "$arch" -aoa -o"${_tmp}" || { write_error "An error occurred while trying to extract $arch"; exit 1; }

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
						pushd "${_tmp}/${dir_name}" >/dev/null || { write_error "A problem was encountered when attempting to access the directory ${_tmp}/${dir_name}"; exit 1; }

						if [[ -f ./run.sh ]]; then
							write_status "Installing package contents: ${dir_name}"
							bash ./run.sh || { write_error "An error occurred while trying to run the run.sh"; popd >/dev/null; exit 1; }
						elif [[ -f ./install.sh ]]; then
							write_status "Installing package contents: ${dir_name}"
							bash ./install.sh || { write_error "An error occurred while trying to run the install.sh"; popd >/dev/null; exit 1; }
						fi

						popd >/dev/null || { write_error "Failure to pop from directory ${dir_name}"; exit 1; }
					done
				); then
					return 1
				fi
			;;
			--wallpaper )
				local _wall_dir="${_my_scriptdir}/${1/--/}"
				chmod 555 -R "${_wall_dir}"
				if  pgrep -f "gnome-shell" &>/dev/null ; then
					system::log_item "Registering GNOME wallpapers in: ${_WALLPAPER_DIR}"
					theme::register_wallpapers_for_gnome "${_WALLPAPER_DIR}" || return 1
					write_status "Setting Wallpaper: file://${_WALLPAPER_DIR}/RTD_Wallpapers_HQ_Public_Domain_024.jpg"
					theme::run_command_in_gnome_user_session "gsettings set org.gnome.desktop.background picture-uri file://${_WALLPAPER_DIR}/RTD_Wallpapers_HQ_Public_Domain_024.jpg"
					theme::run_command_in_gnome_user_session "gsettings set org.gnome.desktop.background picture-uri-dark file://${_WALLPAPER_DIR}/RTD_Wallpapers_HQ_Public_Domain_024.jpg"
				elif  pgrep -f "plasmashell" &>/dev/null ; then
					system::log_item "Registering Plasma wallpapers in: ${_XDG_WALLPAPER_DIR}/"
					theme::register_wallpapers_for_plasma "${_wall_dir}" "${_XDG_WALLPAPER_DIR}" || return 1
				else
					system::log_item "Unknown DE, registering wallpapers in: ${_XDG_WALLPAPER_DIR}/ and /usr/share/backgrounds/"
					theme::register_wallpapers_for_plasma "${_wall_dir}" "${_XDG_WALLPAPER_DIR}" || return 1
					theme::register_wallpapers_for_plasma "${_wall_dir}" "/usr/share/backgrounds" || return 1
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
			system::log_item "Linux OS Found: Attempting to get themes for Linux..."
			if ! hash git &>> "${_LOGFILE}" ; then
				system::log_item "git was not found, attempting to install it..."
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


theme::register_wallpapers_for_gnome ()
{
	local _wallpaper_dir="$1"
	if [[ ! -d "$_wallpaper_dir" ]]; then
		write_error "Directory '$_wallpaper_dir' does not exist."
		return 1
	fi

	local xml_file="oem-backgrounds.xml"
	local dest_dir="/usr/share/gnome-background-properties"
	local dest_file="${dest_dir}/${xml_file}"
	local tmp_xml tmp_new dest_existed=0

	if ! tmp_xml="$(mktemp)"; then
		write_error "Unable to allocate temporary file for wallpaper registration."
		return 1
	fi
	tmp_new="${tmp_xml}.new"
	local cleanup_cmd="rm -f \"$tmp_xml\" \"$tmp_new\""

	if [[ -f "$dest_file" ]]; then
		dest_existed=1
		cp "$dest_file" "$tmp_xml" || { write_error "Failed to copy existing wallpaper registry."; eval "$cleanup_cmd"; return 1; }
	else
		cat > "$tmp_xml" <<-EOF
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
	<wallpapers>
	</wallpapers>
	EOF
	fi

	local -a entries_to_add=()
	local added=0 skipped=0
	shopt -s nullglob
	for i in "$_wallpaper_dir"/*.jpg "$_wallpaper_dir"/*.png; do
		[[ -f "$i" ]] || continue
		if grep -Fq "<filename>$i</filename>" "$tmp_xml"; then
			((skipped++))
			continue
		fi
		read -r -d '' entry <<-EOF || true
	<wallpaper>
	    <name>$(basename "$i")</name>
	    <filename>$i</filename>
	    <options>stretched</options>
	    <pcolor>#8f4a1c</pcolor>
	    <scolor>#8f4a1c</scolor>
	    <shade_type>solid</shade_type>
	</wallpaper>
	EOF
		entries_to_add+=("$entry")
		((added++))
	done
	shopt -u nullglob

	if (( added > 0 )); then
		local add_block
		add_block=$(printf "%s\n" "${entries_to_add[@]}")
		awk -v block="$add_block" '
			BEGIN { inserted=0 }
			/<\/wallpapers>/ && !inserted { print block; inserted=1 }
			{ print }
		' "$tmp_xml" > "$tmp_new" || { write_error "Failed to update wallpaper registry."; eval "$cleanup_cmd"; return 1; }
		mv "$tmp_new" "$tmp_xml"
		mkdir -p "$dest_dir"
		install -m 644 "$tmp_xml" "$dest_file" || { write_error "Unable to install updated wallpaper registry."; eval "$cleanup_cmd"; return 1; }
		write_status "Registered ${added} new GNOME wallpapers (${skipped} already present)."
	elif (( ! dest_existed )); then
		write_warning "No wallpapers found to register for GNOME."
	else
		write_status "No new GNOME wallpapers needed (${skipped} already present)."
	fi
	eval "$cleanup_cmd"
	return 0
}

theme::register_wallpapers_for_plasma () {
	local source_dir="$1"
	local target_dir="${2:-${_XDG_WALLPAPER_DIR:-/usr/share/wallpapers}}"

	if [[ ! -d "$source_dir" ]]; then
		write_error "Directory '$source_dir' does not exist."
		return 1
	fi

	mkdir -p "$target_dir"

	local added=0 skipped=0
	shopt -s nullglob
	for img in "$source_dir"/*.jpg "$source_dir"/*.png; do
		[[ -e "$img" ]] || continue
		local dest_path="${target_dir}/$(basename "$img")"
		if [[ -e "$dest_path" || -L "$dest_path" ]]; then
			if cmp -s "$img" "$dest_path" 2>/dev/null; then
				((skipped++))
				continue
			fi
		fi
		ln -sf "$img" "$dest_path"
		((added++))
	done
	shopt -u nullglob

	write_status "Linked ${added} wallpapers into ${target_dir} for Plasma (${skipped} already present)."
	return 0
}





write_host ()
{
	local _option
	local _text
	local color

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
		*) _text="$1" ;;
	esac
	[[ -z "${_text}" ]] && _text="${color} 💻 $2 $(tput sgr0)"
	echo -e "${_text} "

	# Tell the logging function to log the message requested...
	system::log_item "🧩 💻 ${FUNCNAME[1]}: ${_text}"

}

theme::term::set_colors() {
  	local ecode="\033["
	yellow="${ecode}1;33m"
	endcolor="${ecode}0m"
	green="${ecode}1;32m"
	blue="${ecode}1;34m"
}

theme::write_error()
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
	[ -n "${text}" ] && system::log_item "🧩 💥 ${FUNCNAME[1]}: ${text}"

}


theme::write_warning() {
	local text=$1

	if [[ "${TERMUITXT}" == "nocolor" ]]; then
		[ -n "${text}" ] && echo "🧩 ⚠ ${FUNCNAME[1]}: ${text}"
	else
		[ -n "${text}" ] && echo -e "${yellow}🧩 ⚠ ${FUNCNAME[1]}: ${text}${endcolor}"
	fi

	# Tell the logging function to log the message requested...
	[ -n "${text}" ] && system::log_item "🧩 ⚠ ${FUNCNAME[1]}: ${text}"
	
}


theme::write_status() {
	local text=$1

	if [[ "${TERMUITXT}" == "nocolor" ]] ; then
		[ -n "${text}" ] && echo "🧩 ✓ ${FUNCNAME[1]}: ${text}"
	else
		[ -n "${text}" ] && echo -e "${green}🧩 ✓ ${FUNCNAME[1]}: ${text}${endcolor}"
	fi

	# Tell the logging function to log the message requested...
	[ -n "${text}" ] && system::log_item "🧩 ✓ ${FUNCNAME[1]}: ${text}"
	
}


theme::write_information() {
	local text=$1

	if [[ "${TERMUITXT}" == "nocolor" ]] ; then
		[ -n "${text}" ] && echo -e "🧩 🛈 ${FUNCNAME[1]}: ${text}"
	else
		[ -n "${text}" ] && echo -e "${blue}🧩 🛈 ${FUNCNAME[1]}: ${text}${endcolor}"
	fi

	# Tell the logging function to log the message requested...
	system::log_item "🧩 🛈 ${FUNCNAME[1]}: ${text}"
	
}




theme::system::log_item() {
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

theme::alias_missing_core_functions() {
	# Alias theme functions to core functions if core functions are missing.
	# Use core functions when they exist to behave consistently if sourced.
	#
	local theme_func core_func
	local -a theme_functions=(
		"theme::write_error"
		"theme::write_warning"
		"theme::write_status"
		"theme::write_information"
		"theme::system::log_item"
		"theme::term::set_colors"
	)

	for theme_func in "${theme_functions[@]}"; do
		core_func="${theme_func#theme::}"

		# Skip when a core implementation already exists.
		if declare -F "$core_func" >/dev/null 2>&1; then
			continue
		fi

		# Alias the theme helper so generic calls resolve here.
		if declare -F "$theme_func" >/dev/null 2>&1 && ! alias "$core_func" >/dev/null 2>&1; then
			alias "${core_func}=${theme_func}"
		fi
	done
}






#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#::::::::::::::                                          ::::::::::::::::::::::
#::::::::::::::          Execute tasks                   ::::::::::::::::::::::
#::::::::::::::                                          ::::::::::::::::::::::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::




main() {

	theme::alias_missing_core_functions

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
			write_information "Foced install of ALL themes..."
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
}

main "$*"

#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#::::::::::::::                                          ::::::::::::::::::::::
#::::::::::::::          Finalize.....                   ::::::::::::::::::::::
#::::::::::::::                                          ::::::::::::::::::::::
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
unset _my_scriptdir
unset _potential_dependencies
unset _tmp
