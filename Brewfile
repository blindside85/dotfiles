## where to install homebrew-cask applications
cask_args appdir: '/Applications'

# set-up brew with taps
tap "homebrew/bundle"
tap "homebrew/cask-drivers"
tap "homebrew/cask-fonts"
tap "homebrew/cask-versions"
tap "homebrew/cask"
tap "homebrew/core"
tap "homebrew/services"
tap "mas-cli/tap" # grab apps from the App Store

# brew
brew "awscli"
brew "bat"           # rust-powered alt to `cat`
brew "openssl@1.1"
brew "coreutils"     # GNU replacements for OSX' garbo tools
brew "diff-so-fancy" # much nicer `git diff` visualizer
brew "exiftool"
brew "fd"            # rust-powered alt to `find`
brew "fish"          # best shell ever
brew "fzf"           # rust-powered fuzzy finder cli tool
brew "git"
brew "gnupg"         # used for file encryption/decryption
brew "imagemagick"
brew "jq"
brew "mas"
brew "memcached", restart_service: true
brew "ncdu"
brew "node"
brew "postgresql", restart_service: true
brew "postgis"
brew "pv"            # monitor shell file download progress
brew "rbenv"         # lightweight ruby manager
brew "redis", restart_service: true
brew "ripgrep"       # rust-powered alt to `grep`
brew "tmux"
brew "ykman"         # manage Yubikey from the shell
brew "z"             # directory jumper using 'frecency'

# cask applications
cask "1password"
cask "alfred"
cask "appcleaner"
cask "cyberduck"
cask "dropbox"
cask "firefox-developer-edition"
cask "gas-mask"
cask "google-chrome"
cask "graphiql"
cask "iterm2"
cask "libreoffice"
cask "microsoft-teams"
cask "notion"
cask "p4v" # formerly p4merge
cask "paw"
cask "postico"
cask "rectangle"
cask "spotify"
cask "visual-studio-code"
cask "zoom"

# MacOS App Store apps (must be signed into App Store to work)
mas "Microsoft Remote Desktop", id: 715768417
