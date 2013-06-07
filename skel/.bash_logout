################################################################################
# Bash Logout

# Clear the screen:
clear

# Reset the terminal (clears scrollback):
reset

# Clear the screen when leaving the console:
if [ "${SHLVL}" = 1 ]; then
    [ -x /usr/bin/clear_console ] && /usr/bin/clear_console --quiet
fi
