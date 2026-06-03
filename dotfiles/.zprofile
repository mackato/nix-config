# POSIX 互換の login 設定は .profile に集約。zsh からは sh エミュレートで読む。
[ -f "$HOME/.profile" ] && emulate sh -c '. "$HOME/.profile"'
