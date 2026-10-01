# Installed as /etc/profile.d/carnine-password.sh: warns on every login, on
# the console and over SSH, while the login user still has the image's
# well-known default password. carnine-password-check writes the marker; the
# login shell cannot read /etc/shadow itself.
# shellcheck shell=sh

if [ -e "${CARNINE_PASSWORD_MARKER:-/run/carnine-default-password}" ]; then
    case $- in
        *i*)
            echo
            echo "WARNUNG: Der Benutzer '$(id -un)' hat noch das Standardpasswort."
            echo "Jeder im selben Netz kann sich damit per SSH anmelden."
            echo "Bitte jetzt mit 'passwd' ein eigenes Passwort setzen."
            echo
            echo "WARNING: The user '$(id -un)' still has the default password."
            echo "Anyone on the same network can log in with it over SSH."
            echo "Please set a password of your own now with 'passwd'."
            echo
            ;;
    esac
fi
