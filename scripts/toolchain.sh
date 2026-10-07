# If Xcode is installed but its license hasn't been accepted, `swift` fails;
# fall back to the Command Line Tools in that case.
if ! swift --version >/dev/null 2>&1 && [[ -d /Library/Developer/CommandLineTools ]]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi
