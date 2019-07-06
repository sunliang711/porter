#!/bin/bash
rpath="$(readlink ${BASH_SOURCE})"
if [ -z "$rpath" ];then
    rpath=${BASH_SOURCE}
fi
root="$(cd $(dirname $rpath) && pwd)"
cd "$root"

user="${SUDO_USER:-$(whoami)}"
home="$(eval echo ~$user)"

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
cyan=$(tput setaf 5)
reset=$(tput sgr0)
runAsRoot(){
    verbose=0
    while getopts ":v" opt;do
        case "$opt" in
            v)
                verbose=1
                ;;
            \?)
                echo "Unknown option: \"$OPTARG\""
                exit 1
                ;;
        esac
    done
    shift $((OPTIND-1))
    cmd="$@"
    if [ -z "$cmd" ];then
        echo "${red}Need cmd${reset}"
        exit 1
    fi

    if [ "$verbose" -eq 1 ];then
        echo "run cmd:\"${red}$cmd${reset}\" as root."
    fi

    if (($EUID==0));then
        sh -c "$cmd"
    else
        if ! command -v sudo >/dev/null 2>&1;then
            echo "Need sudo cmd"
            exit 1
        fi
        sudo sh -c "$cmd"
    fi
}

if [ ! -d repos ];then
    mkdir repos
fi

date +%FT%T

cd repos
for line in $(cat ../config);do
    if ! echo $line | grep -q '^[[:blank:]]*#';then
        src=$(echo $line | awk -F'|' '{print $1}')
        dest=$(echo $line | awk -F'|' '{print $2}')
        echo "src: $src"
        echo "dest: $dest"

        # git clone $src
        name="$(echo ${src##*/})"
        if [ ! -d "$name" ];then
            echo "Clone $src to $name..."
            git clone "$src" "$name" || { echo "Clone $src failed."; continue; }
        fi

        cd "$name"
        echo -n "pwd:"
        pwd
        branchName=$(git rev-parse --abbrev-ref HEAD)
        echo "branch name: $branchName"

        if ! git remote -v | grep -q '^o2';then
            git remote add o2 "$dest"
        else
            #if username or password changed.
            git remote set-url o2 "$dest"
        fi
        cd - >/dev/null
        echo -n "pwd:"
        pwd
    fi
done

for line in $(cat ../config);do
    if ! echo $line | grep -q '^[[:blank:]]*#';then
        src=$(echo $line | awk -F'|' '{print $1}')
        dest=$(echo $line | awk -F'|' '{print $2}')

        name="$(echo ${src##*/})"
        cd "$name"
        echo -n "pwd:"
        pwd
        branchName=$(git rev-parse --abbrev-ref HEAD)
        echo "branch name: $branchName"

        echo "git pull $src..."
        git pull && echo "pull OK." || { echo "pull failed.";continue; }
        echo "push to $dest..."
        git push o2 $branchName && echo "porter OK." || { echo "porter failed."; }

        cd - >/dev/null
        echo -n "pwd:"
        pwd
    fi
done
