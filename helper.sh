#!/usr/bin/env bash

# Copyright (C) 2019-2021 alanndz <alanmahmud0@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

# Colors
red=$'\e[1;31m'
grn=$'\e[1;32m'
blu=$'\e[1;34m'
end=$'\e[0m'

ROM_PATH=$(pwd)
arg=${1}
echo $(pwd)

# Blacklisted repos - don't try to merge
blacklist="hardware/qcom/display \
hardware/qcom/media \
hardware/qcom/audio \
hardware/qcom/bt \
hardware/qcom/wlan \
hardware/ril \
vendor/bianca"

merge_rebase_list="frameworks/base \
packages/apps/Settings"


reset_branch () {
  git checkout $2 &> /dev/null
  git fetch $1 $2 &> /dev/null
  git reset --hard $1/$2 &> /dev/null
}

# Logic kanged from some similar script

merge_rebase() {
  local SRC=$1
  local SOURCE=$2
  local REMOTE=$3
  local BRANCH=$4
  local TAG=$5
  local XML_PATH=$6
  local ENV=$7

  repos="$(grep "remote=\"$REMOTE\"" $ROM_PATH/.repo/manifests/$XML_PATH  | awk '{print $2}' | awk -F '"' '{print $2}')"

  for REPO in $repos; do
    if [[ $blacklist =~ $REPO ]]; then
        echo -e "\n$REPO is in blacklist, skipping"
#    elif [[ $merge_rebase_list =~ $REPO ]]; then
     else
        case $REPO in
            build/make) repo="build" ;;
            *) repo=$REPO ;;
        esac

        if [[ $SRC = "los"  ]]; then
           repo_="$(echo $repo | sed 's|/|_|g')"
           repo_url="${SOURCE}_${repo_}"
        elif [[ $SRC = "aosp" ]]; then
           repo_url="$SOURCE/platform/$repo"
        fi

        if wget -q --spider $repo_url; then
           echo -e "$blu \nMerging $REPO $end"
            cd $REPO
            reset_branch $REMOTE $BRANCH
            git fetch -q $repo_url $TAG &> /dev/null
            git branch -D "${BRANCH}-rebase-${TAG}" &> /dev/null
            if ! git checkout "${BRANCH}-upstream" &> /dev/null; then
                echo "${red}Branch ${BRANCH}-upstream not found, please make it manual!${end}"
                cd $ROM_PATH
                continue
            fi
            if git merge FETCH_HEAD -q -m "Merge tag '$TAG' of $repo_url into $BRANCH" --signoff &> /dev/null; then
                if [[ $(git rev-parse HEAD) != $(git rev-parse $REMOTE_NAME/$BRANCH) ]] && [[ $(git diff HEAD $REMOTE_NAME/$BRANCH) ]]; then
                    echo "${grn}Merging $REPO succeeded :) $end"
                fi
                git checkout ${REMOTE}/${BRANCH} -b "${BRANCH}-rebase-${TAG}" &> /dev/null
                if git rebase ${ENV} "${BRANCH}-upstream"; then
                    echo "$REPO" >> $ROM_PATH/success
                    echo "${grn}Rebasing $REPO succeeded :) $end"
                else
                    echo "$REPO" >> $ROM_PATH/failed
                    echo "${red}$REPO Rebasing failed :( $end"
                fi
            else
                echo "$REPO" >> $ROM_PATH/failed
                echo "${red}$REPO merging failed :( $end"
            fi
            cd $ROM_PATH
        fi
    fi
done
}

merge_only() {
  local SRC=$1
  local SOURCE=$2
  local REMOTE=$3
  local BRANCH=$4
  local TAG=$5
  local XML_PATH=$6
  local MERGE=$7
  local RESET_FAILED=$8

  repos="$(grep "remote=\"$REMOTE\"" $ROM_PATH/.repo/manifests/$XML_PATH  | awk '{print $2}' | awk -F '"' '{print $2}')"

  for REPO in $repos; do
    if [[ $blacklist =~ $REPO || $merge_rebase_list =~ $REPO ]]; then
        echo -e "\n$REPO is in blacklist, skipping"
    else
        case $REPO in
            android) repo="manifest" ;;
            build/make) repo="build" ;;
            *) repo=$REPO ;;
        esac

        if [[ $SRC = "los"  ]]; then
           repo_="$(echo $repo | sed 's|/|_|g')"
           repo_url="${SOURCE}_${repo_}"
        elif [[ $SRC = "aosp" ]]; then
           repo_url="$SOURCE/platform/$repo"
        fi

        if wget -q --spider $repo_url; then
            echo -e "$blu \nMerging $REPO $end"
            cd $REPO
            reset_branch $REMOTE $BRANCH
            git fetch -q $repo_url $TAG &> /dev/null
            git branch -D "${BRANCH}-merge-${TAG}" &> /dev/null
            git checkout -b "${BRANCH}-merge-${TAG}" &> /dev/null
            if git merge FETCH_HEAD -q -m "Merge tag '$TAG' of $repo_url into $BRANCH" --signoff &> /dev/null; then
                if [[ $(git rev-parse HEAD) != $(git rev-parse $REMOTE_NAME/$BRANCH) ]] && [[ $(git diff HEAD $REMOTE_NAME/$BRANCH) ]]; then
                    echo "$REPO" >> $ROM_PATH/success
                    echo "${grn}Merging $REPO succeeded :) $end"
                    [[ $MERGE == true ]] && {
                        echo "${grn}Merged to ${BRANCH} Branch $end"
                        git checkout $BRANCH
                        git merge "${BRANCH}-merge-${TAG}"
                    }
                else
                    echo "$REPO - unchanged"
                    reset_branch $REMOTE $BRANCH
                    git branch -D "${BRANCH}-merge-${TAG}" &> /dev/null
#                    git reset --hard $REMOTE_NAME/$BRANCH &> /dev/null
                fi
            else
                echo "$REPO" >> $ROM_PATH/failed
                echo "${red}$REPO merging failed :( $end"
                [[ $RESET_FAILED == true ]] && {
                    echo "${red}Reset to ${BRANCH} $end"
                    git merge --abort
                    reset_branch $REMOTE $BRANCH
                    git branch -D "${BRANCH}-merge-${TAG}"
                }
            fi
            cd $ROM_PATH
        fi
    fi
done
}

if [[ "$arg" == "rebase" ]]; then
while (( ${#} )); do
  case ${1} in
       "-a"|"--aosp") AOSP=true ;;
       "-l"|"--los") LOS=true ;;
       "-x"|"--xml") shift; XML=${1} ;;
       "-t"|"--tag") shift; TAG=${1} ;;
       "-r"|"--remote") shift; REMOTE_NAME=${1} ;;
       "-b"|"--branch") shift; BRANCH=${1} ;;
       "-p"|"--push") PUSH=true ;;
       "-i") IREBASE="-i" ;;
  esac
  shift
done

elif [[ "$arg" == "merge" ]]; then
while (( ${#} )); do
  case ${1} in
       "-a"|"--aosp") AOSP=true ;;
       "-l"|"--los") LOS=true ;;
       "-x"|"--xml") shift; XML=${1} ;;
       "-t"|"--tag") shift; TAG=${1} ;;
       "-r"|"--remote") shift; REMOTE_NAME=${1} ;;
       "-b"|"--branch") shift; BRANCH=${1} ;;
       "-m"|"--merge") MERGE=true ;;
       "-rf"|"--reset-failed") RESET_FAILED=true ;;
       "-p"|"--push") PUSH=true ;;
  esac
  shift
done
fi

# ROM-specific constants
BRANCH=${BRANCH:-12}
REMOTE_NAME=${REMOTE_NAME:-dudu}
XML="${XML:-snippets/bianca.xml}"
MERGE="${MERGE:-false}"
RESET_FAILED="${RESET_FAILED:-false}"

for files in success failed; do
    rm $files 2> /dev/null
    touch $files
done

[[ -z $AOSP && -z $LOS ]] && {
    echo "Argument -a and -l not defined, must defined once!"
    exit
}

[[ -n $AOSP && -n $LOS ]] && {
    echo "Both AOSP and LOS  were specified!"
    exit
}

[[ -z $TAG ]] && {
    echo "Argument -t or --tag must define!"
    exit 1
}

if [[ -n $AOSP && -z $LOS ]]; then
    SRC="aosp"
    SOURCE="https://android.googlesource.com"
elif [[ -n $LOS && -z $AOSP ]]; then
    SRC="los"
    SOURCE="https://github.com/LineageOS/android"
fi

echo $XML

if [[ "$arg" == "rebase" ]]; then
  merge_rebase $SRC $SOURCE $REMOTE_NAME $BRANCH $TAG $XML $IREBASE
elif [[ "$arg" == "merge" ]]; then
  merge_only $SRC $SOURCE $REMOTE_NAME $BRANCH $TAG $XML $MERGE $RESET_FAILED
fi

echo -e "$red \nThese repos failed merging: \n $end"
cat failed
echo -e "$grn \nThese repos succeeded merging: \n $end"
cat success

if [[ -n $PUSH ]]; then
    for REPO in $(cat success); do
        cd $REPO
        echo -e "Pushing $REPO ..."
        if [[ $MERGE == true ]]; then
            git push -q -f $REMOTE_NAME "${BRANCH}-${arg}-${TAG}" &> /dev/null
        else
            git push -q -f $REMOTE_NAME $BRANCH &> /dev/null
        fi
        cd $ROM_PATH
    done
fi

rm failed success

