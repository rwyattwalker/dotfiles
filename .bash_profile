if [ -f ~/.bashrc ]; then
  . ~/.bashrc
fi
<<<<<<< HEAD
=======
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
  exec startx &>/dev/null
fi
>>>>>>> 87a2f8008632a719d54c9cc7637971cac434d703
