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
tap "vitorgalvao/tiny-scripts" # contribute to Homebrew


# brew
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
brew "vitorgalvao/tiny-scripts/cask-repair" # used in Homebrew contributions

# cask applications
cask "1password"
cask "adoptopenjdk" # screaming-frog-seo-spider dependency (java 7+)
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
cask "screaming-frog-seo-spider"
cask "spotify"
cask "visual-studio-code"

# MacOS App Store apps
mas "Microsoft Remote Desktop", id: 715768417
