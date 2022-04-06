#!/bin/bash
#
# Copyright (C) 2022 Bianca Project
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
#####
# Rebase your local working branches onto a new "upstream" branch.
# Local branch list is defined in branches.list
# (and can be created with branches_save.sh)
# If the upstream branch doesn't exist (eg perhaps in lineage-sdk),
# simply switch the working branch instead.

# Colors
red=$'\e[1;31m'
grn=$'\e[1;32m'
blu=$'\e[1;34m'
end=$'\e[0m'

if [ ! -e "build/envsetup.sh" ]; then
    echo "Must run from root of repo"
    exit 1
fi

if [ "$#" -lt 2 ]; then
    echo "Usage ${0} <remote> <branch> <optional args like --force or other>"
    exit 1
fi

REMOTE="${1}"
BRANCH="${2}"
ARGS="${3}"

echo "$ARGS"

TOP="${PWD}"
BRANCHLIST="${TOP}/branches.list"

cat "${BRANCHLIST}" | while read l; do
    set ${l}
    PROJECTPATH="${1}"
    cd "${TOP}/${PROJECTPATH}"

    if git push $ARGS "${REMOTE}" "${BRANCH}" > /dev/null
    then
        echo -e "${TOP}/${PROJECTPATH} $grn Success $end"
    else
        echo -e "${TOP}/${PROJECTPATH} $red Failed $end"
    fi
done
