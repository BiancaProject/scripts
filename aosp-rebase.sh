#!/bin/bash
#
# Copyright (C) 2017 The LineageOS Project
$ Copyright (C) 2022 Bianca Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Colors
red=$'\e[1;31m'
grn=$'\e[1;32m'
blu=$'\e[1;34m'
end=$'\e[0m'

usage() {
    echo "Usage ${0} <branch> <newaosptag>"
}

# Verify argument count
if [ "$#" -ne 2 ]; then
    usage
    exit 1
fi

if [ ! -e "build/envsetup.sh" ]; then
    echo "Must be run from the top level repo dir"
    exit 1
fi

BRANCH="${1}"
TAG="${2}"

# Environment 
TOP=$(pwd)
REMOTE="dudu"
AOSP="https://android.googlesource.com"
MANIFEST="${TOP}/.repo/manifests/snippets/bianca.xml"
BLACKLIST=$(cat "${TOP}/scripts/blacklist")

# Build list of Bianca Project forked repos
PROJECTPATHS=$(grep "remote=\"${REMOTE}" "${MANIFEST}" | sed -n 's/.*path="\([^"]\+\)".*/\1/p')

# Make sure manifest and forked repos are in a consistent state
echo "#### Verifying there are no uncommitted changes on Bianca Project forked AOSP projects ####"
for PROJECTPATH in ${PROJECTPATHS} .repo/manifests; do
    cd "${TOP}/${PROJECTPATH}"
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "Path ${PROJECTPATH} has uncommitted changes. Please fix."
        exit 1
    fi
done
echo "#### Verification complete - no uncommitted changes found ####"

reset_branch () {
    git checkout $BRANCH &> /dev/null
    git fetch $REMOTE $BRANCH &> /dev/null
    git reset --hard $REMOTE/$BRANCH &> /dev/null
}

for files in success failed; do
    rm $files 2> /dev/null
    touch $files
done

for PROJECTPATH in ${PROJECTPATHS}; do
    if [[ "${BLACKLIST}" =~ "${PROJECTPATH}" ]]; then
       continue
    fi
    if [ ! -d "${PROJECTPATH}" ]; then
       continue
    fi

    case $PROJECTPATH in
       build/make) repo_url="$AOSP/platform/build" ;;
       *) repo_url="$AOSP/platform/$PROJECTPATH" ;;
    esac

    if wget -q --spider $repo_url; then
        echo -e "$blu \nRebasaing $PROJECTPATH $end"
        cd "${TOP}/${PROJECTPATH}"
        git checkout "${BRANCH}"
        git fetch -q $repo_url $TAG &> /dev/null
        git branch -D "${BRANCH}-rebase-${TAG}" &> /dev/null
        git checkout -b "${BRANCH}-rebase-${TAG}" &> /dev/null
        if git rebase FETCH_HEAD &> /dev/null; then
            if [[ $(git rev-parse HEAD) != $(git rev-parse $REMOTE_NAME/$BRANCH) ]] && [[ $(git diff HEAD $REMOTE_NAME/$BRANCH) ]]; then
                echo "$PROJECTPATH" >> $ROM_PATH/success
                echo "${grn}Rebase $PROJECTPATH succeeded $end"
            else
                echo "$PROJECTPATH - unchanged"
                git checkout "${BRANCH}"
                git branch -D "${BRANCH}-rebase-${TAG}" &> /dev/null
            fi
        else
            echo "$PROJECTPATH" >> $TOP/failed
            echo "${red}$REPO Rebasing failed :( $end"
        fi
        cd "${TOP}"
    fi
done

echo -e "$red \nThese repos failed rebasing: \n $end"
cat failed
echo -e "$grn \nThese repos succeeded rebasing: \n $end"
cat success