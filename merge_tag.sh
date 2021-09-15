#!/usr/bin/env bash
# Script to merge latest AOSP tag in BiancaProject source
# Can be adapted to other AOSP-based ROMs as well
#
# After completion, you'll get the following files in the ROM source dir:
# 	success - repos where merge succeeded
# 	failed - repos where merge failed
#
# Also supports auto-pushing of repos where merge succeeded
#
# Usage: Just run the script in root of ROM source
#

# Colors
red=$'\e[1;31m'
grn=$'\e[1;32m'
blu=$'\e[1;34m'
end=$'\e[0m'

while (( ${#} )); do
  case ${1} in
       "-a"|"--aosp") AOSP=true ;;
       "-l"|"--los") LOS=true ;;
       "-x"|"--xml") shift; XML=${1} ;;
       "-t"|"--tag") shift; TAG=${1} ;;
       "-r"|"--remote") shift; REMOTE_NAME=${1} ;;
       "-b"|"--branch") shift; BRANCH=${1} ;;
       "-m"|"--merge") shift; MERGE=true ;;
       "-rf"|"--reset-failed") shift; RESET_FAILED=true ;;
  esac
  shift
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

# Assumes user is running the script in root of source
ROM_PATH=$(pwd)

# ROM-specific constants
BRANCH=${BRANCH:-11}
REMOTE_NAME=${REMOTE_NAME:-dudu}
REPO_XML_PATH="${XML:-snippets/bianca.xml}"

# Blacklisted repos - don't try to merge
blacklist="android \
hardware/qcom/display \
hardware/qcom/media \
hardware/qcom/audio \
hardware/qcom/bt \
hardware/qcom/wlan \
hardware/ril \
vendor/bianca \
prebuilts/r8"

# Get merge tag from user
# read -p "Enter the AOSP tag you want to merge: " TAG

# Set the base URL for all repositories to be pulled from
if [[ -n $AOSP && -z $LOS ]]; then
    SOURCE="https://android.googlesource.com"
elif [[ -n $LOS && -z $AOSP ]]; then
    SOURCE="https://github.com/LineageOS/android"
fi

echo $SOURCE

reset_branch () {
  git checkout $BRANCH &> /dev/null
  git fetch $REMOTE_NAME $BRANCH &> /dev/null
  git reset --hard $REMOTE_NAME/$BRANCH &> /dev/null
}

# Logic kanged from some similar script
repos="$(grep "remote=\"$REMOTE_NAME\"" $ROM_PATH/.repo/manifests/$REPO_XML_PATH  | awk '{print $2}' | awk -F '"' '{print $2}')"

for files in success failed; do
    rm $files 2> /dev/null
    touch $files
done

for REPO in $repos; do
    if [[ $blacklist =~ $REPO ]]; then
        echo -e "\n$REPO is in blacklist, skipping"
    else
        case $REPO in
            build/make) repo="build" ;;
            *) repo=$REPO ;;
        esac


        if [[ -n $LOS && -z $AOSP ]]; then
           repo_="$(echo $repo | sed 's|/|_|g')"
           repo_url="${SOURCE}_${repo_}"
        elif [[ -n $AOSP && -z $LOS ]]; then
           repo_url="$SOURCE/platform/$repo"
        fi

        if wget -q --spider $repo_url; then
            echo -e "$blu \nMerging $REPO $end"
            cd $REPO
            reset_branch
            git fetch -q $repo_url $TAG &> /dev/null
            git branch -D "${BRANCH}-merge-${TAG}" &> /dev/null
            git checkout -b "${BRANCH}-merge-${TAG}" &> /dev/null
            if git merge FETCH_HEAD -q -m "Merge tag '$TAG' of $repo_url into $BRANCH" --signoff &> /dev/null; then
                if [[ $(git rev-parse HEAD) != $(git rev-parse $REMOTE_NAME/$BRANCH) ]] && [[ $(git diff HEAD $REMOTE_NAME/$BRANCH) ]]; then
                    echo "$REPO" >> $ROM_PATH/success
                    echo "${grn}Merging $REPO succeeded :) $end"
                    [[ -n $MERGE ]] && {
                        echo "${grn}Merged to ${BRANCH} Branch $end"
                        git checkout $BRANCH
                        git merge "${BRANCH}-merge-${TAG}"
                    }
                else
                    echo "$REPO - unchanged"
                    reset_branch
                    git branch -D "${BRANCH}-merge-${TAG}" &> /dev/null
#                    git reset --hard $REMOTE_NAME/$BRANCH &> /dev/null
                fi
            else
                echo "$REPO" >> $ROM_PATH/failed
                echo "${red}$REPO merging failed :( $end"
                [[ -n $RESET_FAILED ]] && {
                    echo "${red}Reset to ${BRANCH} $end"
                    git merge --abort
                    reset_branch
                    git branch -D "${BRANCH}-merge-${TAG}"
                }
            fi
            cd $ROM_PATH
        fi
    fi
done

echo -e "$red \nThese repos failed merging: \n $end"
cat failed
echo -e "$grn \nThese repos succeeded merging: \n $end"
cat success

echo $red
read -p "Do you want to push the succesfully merged repos? (Y/N): " PUSH
echo $end

if [[ $PUSH == "Y" ]] || [[ $PUSH == "y" ]]; then
    # Push succesfully merged repos
    for REPO in $(cat success); do
        cd $REPO
        echo -e "Pushing $REPO ..."
        git push -q -f $REMOTE_NAME "11-merge-${TAG}" &> /dev/null
        cd $ROM_PATH
    done
fi

echo -e "\n${blu}All done :) $end"
