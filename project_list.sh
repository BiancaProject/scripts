#!/bin/bash
#
# Copyright (C) 2020-2022 Bianca Project
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

if [ ! -e "build/envsetup.sh" ]; then
    echo "Must run from root of repo"
    exit 1
fi

TOP="${PWD}"
LIST="${TOP}/project.list"
BLACKLIST=$(cat "${TOP}/scripts/blacklist")
MANIFEST="${TOP}/.repo/manifests/snippets/bianca.xml"

# Build list of Bianca Project forked repos
PROJECTPATHS=$(grep "remote=\"dudu" "${MANIFEST}" | sed -n 's/.*path="\([^"]\+\)".*/\1/p')

for PROJECTPATH in ${PROJECTPATHS}; do
    if [[ "${BLACKLIST}" =~ "${PROJECTPATH}" ]]; then
        continue
    fi

    echo "${PROJECTPATH}"
done | sort > "${LIST}"

