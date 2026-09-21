#!/bin/bash

#
# Copyright (c) 2021 Matthew Penner
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

set -Eeuo pipefail

# Give everything time to initialize for preventing SteamCMD deadlock
sleep 1

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2); exit}')
INTERNAL_IP=${INTERNAL_IP:-127.0.0.1}
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

# Convert all of the "{{VARIABLE}}" parts of the command into the expected shell
# variable format of "${VARIABLE}" before evaluating the string and automatically
# replacing the values.
PARSED=$(printf '%s' "${STARTUP:?STARTUP is not set}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")

## just in case someone removed the defaults.
if [[ -z "${STEAM_USER:-}" ]]; then
    echo "Steam user is not set; using anonymous login."
    STEAM_USER=anonymous
    STEAM_PASS=""
    STEAM_AUTH=""
else
    echo "Steam user is set to ${STEAM_USER}."
fi

# Update optional server content without persisting credentials in .git/config.
if [[ "${AUTO_GIT_UPDATE:-0}" == "1" ]]; then
    git_folder=${GIT_FOLDER:-.}
    if [[ "${git_folder}" = /* || "${git_folder}" == *..* ]]; then
        echo "GIT_FOLDER must be a relative path without '..'." >&2
        exit 1
    fi

    if [[ -d "${git_folder}/.git" ]]; then
        git_address=${GIT_ADDRESS:-}
        if [[ -n "${git_address}" ]]; then
            [[ "${git_address}" == *.git ]] || git_address="${git_address}.git"
            if git -C "${git_folder}" remote get-url origin >/dev/null 2>&1; then
                git -C "${git_folder}" remote set-url origin "${git_address}"
            else
                git -C "${git_folder}" remote add origin "${git_address}"
            fi
        elif ! git -C "${git_folder}" remote get-url origin >/dev/null 2>&1; then
            echo "Git repository in ${git_folder} has no origin and GIT_ADDRESS is empty; skipping repository update."
            git_folder=
        fi

        git_args=(-C "${git_folder}")
        if [[ -n "${USERNAME:-}" && -n "${ACCESS_TOKEN:-}" ]]; then
            git_auth=$(printf '%s' "${USERNAME}:${ACCESS_TOKEN}" | base64 -w 0)
            git_args=(-c "http.extraHeader=Authorization: Basic ${git_auth}" "${git_args[@]}")
        fi

        if [[ -n "${git_folder}" ]]; then
            if git "${git_args[@]}" fetch --depth=1 origin "${BRANCH:-HEAD}"; then
                git "${git_args[@]}" reset --hard FETCH_HEAD || \
                    echo "Git checkout failed; keeping the current server files."
            else
                echo "Git fetch failed; keeping the current server files."
            fi
        fi
        unset git_auth 2>/dev/null || true
    else
        echo "No Git repository found in ${git_folder}; skipping repository update."
    fi
fi

# Update the game unless explicitly disabled.
if [[ "${AUTO_UPDATE:-1}" == "1" ]]; then
    if [[ -n "${SRCDS_APPID:-}" ]]; then
        steamcmd_args=(
            +force_install_dir /home/container
            +login "${STEAM_USER}" "${STEAM_PASS:-}" "${STEAM_AUTH:-}"
            +app_update "${SRCDS_APPID}"
        )

        [[ -z "${SRCDS_BETAID:-}" ]] || steamcmd_args+=(-beta "${SRCDS_BETAID}")
        [[ -z "${SRCDS_BETAPASS:-}" ]] || steamcmd_args+=(-betapassword "${SRCDS_BETAPASS}")
        [[ -z "${HLDS_GAME:-}" ]] || steamcmd_args+=(+app_set_config 90 mod "${HLDS_GAME}")
        [[ -z "${VALIDATE:-}" ]] || steamcmd_args+=(validate)
        steamcmd_args+=(+quit)

        ./steamcmd/steamcmd.sh "${steamcmd_args[@]}"
    else
        echo "No AppID is set; skipping the game update."
    fi
else
    echo "Automatic game updates are disabled."
fi

# Display the command we're running in the output, and then execute it with the env
# from the container itself.
printf "\033[1m\033[33mcontainer@refoseldev~ \033[0m%s\n" "$PARSED"
exec /bin/bash -c "${PARSED}"
