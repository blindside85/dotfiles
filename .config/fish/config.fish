set fish_greeting
if status is-interactive

	# set some globally-needed vars
	set -gx TERM 'xterm-256color'
	set -gx VISUAL 'vim'
	set -gx EDITOR $VISUAL
	set -gx GPG_TTY (tty)
	set -gx AWS_REGION 'us-east-2'
	set -gx GOPRIVATE 'github.com/Trust-Will/*'
	set -gx RIPGREP_CONFIG_PATH ~/.ripgreprc
	set -gx FZF_DEFAULT_COMMAND 'fd -t f'
	set -gx FZF_DEFAULT_OPTS "
    	--bind='ctrl-o:execute(code {})+abort'
    	--color=fg+:200,bg+:-1
	"
	set -gx SKIM_DEFAULT_OPTIONS "
    	--color=fg+:200,bg+:-1
	"
	set -g fish_user_paths /opt/homebrew/bin $fish_user_paths
	set -g fish_user_paths /opt/homebrew/sbin $fish_user_paths
	set -g fish_user_paths /usr/local/bin $fish_user_paths
    set -g fish_user_paths /Library/TeX/texbin $fish_user_paths
	set -x GITREPO (basename (git rev-parse --show-toplevel 2>/dev/null) 2>/dev/null)

	# setup custom abbreviations (NOT aliases)
	if not set -q fish_initialized
    	set -U fish_initialized true
    	abbr -a gs  'git status -sb'
    	abbr -a gco 'git checkout'
    	abbr -a gd  'git diff --color-words | diff-so-fancy | less -r'
    	abbr -a gdc 'git diff --cached --color-words | diff-so-fancy | less -r'
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

	# init custom Starship prompt
	starship init fish | source
	# init zoxide directory jumper
	zoxide init fish | source
	# pull in my custom functions / scripts / aliases
	source ~/.config/fish/functions/personal.fish
	source ~/.config/fish/functions/*personal.fish
	source /opt/homebrew/opt/asdf/libexec/asdf.fish

end

set -gx VOLTA_HOME "$HOME/.volta"
set -gx PATH "$VOLTA_HOME/bin" $PATH
