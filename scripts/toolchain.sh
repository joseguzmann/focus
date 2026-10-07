# Si Xcode está instalado pero sin la licencia aceptada, `swift` falla;
# en ese caso se usan las Command Line Tools.
if ! swift --version >/dev/null 2>&1 && [[ -d /Library/Developer/CommandLineTools ]]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
