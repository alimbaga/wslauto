#!/bin/sh

# Modified version of LARBS for an Ubuntu WSL dev environment

### OPTIONS AND VARIABLES ###

while getopts ":a:r:b:p:h" o; do case "${o}" in
    h) printf "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -p: Dependencies and programs csv (local file or url)\\n  -h: Show this message\\n" && exit ;;
    r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit ;;
    b) repobranch=${OPTARG} ;;
    p) progsfile=${OPTARG} ;;
    *) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;
esac done

[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/alimbaga/wsldotfiles.git"
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/alimbaga/wslauto/master/progs.csv"
[ -z "$repobranch" ] && repobranch="master"

repodir="$HOME/.local/src"

### FUNCTIONS ###

installpkg(){ sudo apt install -y "$1" >/dev/null 2>&1 ;}

grepseq="\"^[PGU]*,\""

error() { clear; printf "ERROR:\\n%s\\n" "$1"; exit;}

welcomemsg() { \
  dialog --title "Welcome $(whoami)!" --msgbox "Welcome to WSL Auto script!" 10 60

    dialog --colors --title "Important Note!" --yes-label "All ready!" --no-label "Return..." --yesno "Be sure you have sudo access.\\n\\nIf not, the installation of some programs might fail." 8 70
}

maininstall() { # Installs all needed programs from main repo.
    dialog --title "Auto Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
    installpkg "$1"
}

gitmakeinstall() {
    progname="$(basename "$1" .git)"
    dir="$repodir/$progname"
    dialog --title "Auton Installation" --infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 5 70
    sudo -u "$(whoami)" git clone --depth 1 "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return ; sudo -u "$(whoami)" git pull --force origin master;}
    cd "$dir" || exit
    make >/dev/null 2>&1
    make install >/dev/null 2>&1
    cd /tmp || return ;
}

pipinstall() { \
	dialog --title "Auto Installation" --infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 5 70
	command -v pip || installpkg python-pip >/dev/null 2>&1
	yes | pip install "$1"
	}

installationloop() { \
    ([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' | eval grep "$grepseq" > /tmp/progs.csv
    total=$(wc -l < /tmp/progs.csv)
    while IFS=, read -r tag program comment; do
        n=$((n+1))
        echo "$comment" | grep "^\".*\"$" >/dev/null 2>&1 && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
        case "$tag" in
            "G") gitmakeinstall "$program" "$comment" ;;
            "P") pipinstall "$program" "$comment" ;;
            *) maininstall "$program" "$comment" ;;
        esac
    done < /tmp/progs.csv ;
}

putgitrepo() {
    # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
    dialog --infobox "Downloading and installing config files..." 4 60
    [ -z "$3" ] && branch="master" || branch="$repobranch"
    dir=$(mktemp -d)
    [ ! -d "$2" ] && mkdir -p "$2"
    chown -R "$(whoami)":wheel "$dir" "$2"
    sudo -u "$(whoami)" git clone --recursive -b "$branch" --depth 1 "$1" "$dir" >/dev/null 2>&1
    sudo -u "$(whoami)" cp -rfT "$dir" "$2"
}

finalize() { \
    dialog --infobox "Preparing welcome message..." 4 50
    dialog --title "All done!" --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, restart your terminal.\\n\\n" 12 80
}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

sudo apt update && sudo apt upgrade || error "Could not update and upgrade system"

welcomemsg

# Check if user is root on Arch distro. Install dialog.
installpkg dialog || error "Could not install dialog :("

dialog --title "Auto Installation" --infobox "Installing \`curl\` and \`git\` for installing other software required for the installation of other programs." 5 70
installpkg curl
installpkg git

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop

# Install the dotfiles in the user's home directory
putgitrepo "$dotfilesrepo" "/home/$(whoami)" "$repobranch"
rm -f "/home/$(whoami)/README.md" "/home/$(whoami)/LICENSE"

# Install the tmux plugin manager
putgitrepo "https://github.com/tmux-plugins/tpm" "/home/$(whoami)/.tmux/plugins/tpm" "master"

# make git ignore deleted LICENSE & README.md files
git update-index --assume-unchanged "/home/$(whoami)/README.md"
git update-index --assume-unchanged "/home/$(whoami)/LICENSE"

# Make zsh the default shell for the user.
sudo sed -i "s/^$(whoami):\(.*\):\/bin\/\S*/$(whoami):\1:\/bin\/zsh/" /etc/passwd

# Make zsh log directory
mkdir -p "$HOME/.logs/zsh-history/"

finalize

clear
