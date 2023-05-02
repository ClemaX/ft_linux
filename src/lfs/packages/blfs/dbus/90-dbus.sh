# shellcheck shell=sh

if [ "${DISPLAY}" = ":0" ] && [ "${XDG_SESSION_TYPE}" = "x11" ]; then
  dbus-launch --exit-with-x11
fi
