# set some globally-needed vars
set -gx TERM 'xterm-256color'
set -gx VISUAL 'vim'
set -gx EDITOR $VISUAL
set -gx RIPGREP_CONFIG_PATH ~/.ripgreprc
set -gx FZF_DEFAULT_COMMAND 'fd -t f'
set -gx FZF_DEFAULT_OPTS "
  --bind='ctrl-o:execute(code {})+abort'
  --color fg:-1,bg:-1,hl:230,fg+:3,bg+:233,hl+:229
  --color info:150,prompt:110,spinner:150,pointer:167,marker:174
"
# link Rubies to Homebrew's OpenSSL 1.1 (which is upgraded)
set -x RUBY_CONFIGURE_OPTS "--with-openssl-dir="(brew --prefix openssl@1.1)
set -g fish_user_paths "/usr/local/sbin" $fish_user_paths
set -g fish_user_paths ~/bin $fish_user_paths
set -g fish_user_paths /Applications/Postgres.app/Contents/Versions/latest/bin $fish_user_paths
set -x GITREPO (basename (git rev-parse --show-toplevel 2>/dev/null) 2>/dev/null)

# setup custom abbreviations (NOT aliases)
if not set -q fish_initialized
  set -U fish_initialized true
  abbr -a gs  'git status -sb'
  abbr -a gco 'git checkout'
  abbr -a gd  'git diff'
  abbr -a gdc 'git diff --cached'
  abbr -a gf  'git fetch --all'
  abbr -a gls 'git log --pretty=format:"%h - %Cgreen%ad%Creset %s %Cblueby %an %d%Creset" --author="Jesse Dupuy" --date=short'
  abbr -a gsl 'git stash list'
  abbr -a gmt 'git mergetool'
  abbr -a gma 'git merge --abort'
  abbr -a mb  'git merge --no-ff --no-commit'
  abbr -a gp  'git push'
  abbr -a gph 'git push origin HEAD'
  abbr -a gpp 'git pull -p'
  abbr -a kb  'git branch -d'
  abbr -a kbr 'git push origin :'
end

source ~/.config/fish/functions/personal.fish

test -e {$HOME}/.iterm2_shell_integration.fish
and source {$HOME}/.iterm2_shell_integration.fish

# Load rbenv automatically
status --is-interactive; and source (rbenv init -|psub)
starship init fish | source
