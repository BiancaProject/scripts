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

if [ ! -e "build/envsetup.sh" ]; then
    echo "Must run from root of repo"
    exit 1
fi

usage() {
  echo "Usage ${0} <start|list|merger|save|backup|branch|rebase|restore|reset|checkout|push> <argument>"
  exit 1
}

ARG="$1"
TOP=$(pwd)
SC="${TOP}/scripts"

case "${ARG}" in
  merger)
    "${SC}/aosp-merger.sh" "${@:2}" ;;
  rebase)
    "${SC}/aosp-rebase.sh" "${@:2}" ;;
  start)
    "${SC}/project_start.sh" "${@:2}" ;;
  save|branch)
    "${SC}/branches_${ARG}.sh" ;;
  backup|restore|reset|checkout|push)
    "${SC}/branches_${ARG}.sh" "${@:2}" ;;
  list)
    "${SC}/project_${ARG}.sh" ;;
  *)
    usage ;;
esac
