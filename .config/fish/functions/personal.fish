#=== GLOBAL VALUES ===#
set editor "code"
set -gx project_path "$HOME/projects"

#=== ALIASES ===#
alias ll "eza -la --classify --color-scale --git-ignore"
alias fzpv "fzf --preview 'bat --color \"always\" {}'"
alias gph "git push origin HEAD"
alias ip "dig +short myip.opendns.com @resolver1.opendns.com"
alias bubu "brew update && brew upgrade"
alias dsp "docker system prune -a --volumes --force"
alias ghb "gh browse"
alias cfg "/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME"
alias nc "numi-cli"
alias ff "fresh_fish"

#=== CUSTOM FUNCTIONS ===#

## === HELPERS ===
function notify_me
  osascript -e 'display notification "needs attention!" with title "Your terminal" sound name "Submarine"'
end

function file_list -d "Get list of files for further use in methods"
  git status -s | fzf --height 20% --layout=reverse --border --multi --ansi | awk '{split($0,a); print a[2]}'
end

function list_branches -d "List current git branches"
  git for-each-ref --format='%(refname:short)' refs/heads | fzf --height 25% --layout=reverse --border
end

function get_main_branch -d "Get the main branch for the current git repo"
  git remote show origin | grep 'HEAD branch' | sed 's/.*: //'
end

function attack -d "Execute load test against URL at differing rates and get report" --argument-names users
  echo "GET http://localhost:8081/health" | vegeta attack -duration=30s -workers=$users | tee results.bin | vegeta report
end

## === FISH ===
function fresh_fish -d "Reload fish to remove need to restart iTerm"
  set -e fish_initialized
  source ~/.config/fish/config.fish
end

function edit_fish -d "Open fish configs dir"
  eval $editor ~/.config/fish
end

function edit_personal -d "Edit my custom fish scripting file"
  eval $editor ~/.config/fish/functions/personal.fish
end

function reset_abbrs -d "Unset and refresh all fish abbreviations"
  for abbr in (set | rg '^_fish_abbr' | rg '(^\w+).*$' -r '$1')
	set -e $abbr
  end
  set -e fish_initialized
  fresh_fish
end

## === OS ===
function edit_host -d "Edit hosts file in text editor"
  sudo -S $editor --user-data-dir="~/Library/Application\ Support/Code" /private/etc/hosts
end

function edit_ssh -d "Edit SSH config in text editor"
  sudo -S $editor ~/.ssh/config
end

function fssh -d "Fuzzy-find ssh host via ag and ssh into it"
  rg '^host [^*]' ~/.ssh/config | cut -d ' ' -f 2 | fzf | read -l result
  and ssh "$result"
end

function pc -d "Figure out if anything is running on port 3000" --argument-names 'port'
  lsof -wni tcp:$port
end

function pk -d "Kill all processes for a given service"
  pkill -9 -f (lsof | fzf)
end

function top_10 -d "lists the top 10 used commands in the current cli"
  history | awk '{CMD[$2]++;count++;}END { for (a in CMD)print CMD[a] " " CMD[a]/count*100 "% " a;}' | grep -v "./" | column -c3 -s " " -t | sort -nr | nl |  head -n10
end

function big_10 -d "List top X largest directories in the current folder" --argument-names 'count'
  set -q $count or set $count 20
  du -hs * | gsort -hr | head -$count
end

function weigh_in -d "List directories sorted by descending size within current folder"
  # found here: https://serverfault.com/a/62424
  du -d 1 | sort -nr | cut -f2 | sed 's/ /\\ /g' | xargs du -sh
end

function fzrg -a 'search' -d "Use `rg` to search through codebase for a term, use `fzf` to browse the results, [enter] to open the file"
  if test -n "$search"
	set match (rg --color=never --line-number $search | fzf --height 80% --reverse --preview-window down:40% --no-multi --delimiter : --preview "bat --color=always --line-range {2}: {1}")
	set file (echo $match | cut -d ':' -f1)

	if test -n "$file"
  	# it'd be nice if we didn't need -g, which is vscode-specific, but alas
  	eval $editor -g $file:(echo $match | cut -d ':' -f2)
	end
  else
	echo "Error: no search query provided"
  end
end

function fe -d "Open all selected files in editor"
  set files (file_list)
  if test -n "$files"
	eval $editor $files
  else
	echo 'No files chosen'
  end
end

function nv -d "Use fzf to choose files to pass to the editor"
  set files (fzf --multi)
  if test -n "$files"
	eval $editor $files
  else
	echo 'No files chosen for editing...'
  end
end

function sp -d "Use fzf to choose current project to switch to" --argument-names project
  set -q project[1]; or set project ''
  set project (fd -t d -d 1 . $project_path | cut -d '/' -f 5 | fzf --height 20% --layout=reverse --border --query=$project --select-1 --header 'choose a project to switch to')
  if test -n "$project"
	cd $project_path/$project
  else
	echo 'aight, guess we stayin here ¯\_(ツ)_/¯'
  end
end

function sc -d "Use fzf to choose a project to switch the current VSCode window to" --argument-names project
  set -q project[1]; or set project ''
  set project (fd -t d -d 1 . $project_path | cut -d '/' -f 5 | fzf --height 20% --layout=reverse --border --query=$project --select-1 --header 'choose a project to switch to')
  if test -n "$project"
	code -r $project_path/$project
  else
	echo 'aight, guess we stayin here ¯\_(ツ)_/¯'
  end
end

## === GIT ===
function gte -d "Generate a valid Trust & Will email address for testing"
  git config user.email | sed "s/@/+$(date +%s)@/" | tee /dev/tty | pbcopy
end

function nb -d "Create new branch based on desired remote, with sane default" --argument-names branch upstream
  set -q upstream[1]; or set upstream 'origin/develop'

  git checkout -t -b $branch $upstream
end

function fco -d "Use `fzf` to choose which branch to check out" --argument-names branch
  set -q branch[1]; or set branch ''
  git for-each-ref --format='%(refname:short)' refs/heads | fzf --height 20% --layout=reverse --border --query=$branch --select-1 | xargs git checkout
end

function faf -d "Use `fzf` to choose which files to stage"
  set files (file_list)
  if test -n "$files"
	eval git add $files
  else
	echo 'No files chosen'
  end
  git status -sb
end

function commit_compress -d "Calculate num of commits ahead of upstream and squash them into a single commit"
  set upstream (git rev-parse --abbrev-ref @{u})
  set ahead (git rev-list --count @{u}..HEAD)

  if test $ahead -gt 0
	git rebase -i HEAD~$ahead
  else
	echo "in sync with $upstream"
  end
end

function snag -d "Pick desired files from a chosen branch"
  # use fzf to choose source branch to snag files FROM
  set branch (list_branches)
  # avoid doing work if branch isn't set
  if test -n "$branch"
	# use fzf to choose files that differ from current branch
	set files (git diff --name-only $branch | fzf --height 50% --layout=reverse --border --multi --preview="git diff ..$branch -- {}")
  end
  # avoid checking out branch if files aren't specified
  if test -n "$files"
	git checkout $branch $files
  end
end

function branch_refresh -d "Remove current copies of branch and refresh with new versions from origin"
  # use fzf to choose source branch to snag files FROM
  set branch (list_branches)
  # avoid doing work if branch isn't set
  if test -n "$branch"
	git branch -D $branch
	git branch -dr origin/$branch
	git fetch
	git checkout -b $branch origin/$branch
  end
end

function check_stash -d "Diff files from a chosen git stash"
  # use fzf to choose stash to check
  set stash (git stash list | fzf --height 20% --layout=reverse --border | cut -d : -f 1)
  # avoid doing work if branch isn't set
  if test -n "$stash"
	# use fzf to choose files that differ from current branch
	set files (git stash show -p $stash --name-only | fzf --height 50% --layout=reverse --border --multi --preview="git diff $stash^1 $stash -- {}")
  end
  # avoid checking out files from stash if files aren't specified
  if test -n "$files"
	git checkout $stash -- $files
  end
end

function glg -d "Pretty log of all [author's] commits" --argument-names 'author'
  set -q author[1] || set author "Jesse Dupuy"
  git log --pretty=format:"%h - %Cgreen%ad%Creset %s %Cblueby %an %d%Creset" --author=$author --no-merges --date=short
end

function fzlg -d "Interactive git log using fzf" --argument-names 'author'
  set viewGitLogLine "echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I COMMIT sh -c 'git show --stat --color COMMIT'"
  set viewGitLogCommit "echo {} | grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I COMMIT sh -c 'git diff --color COMMIT'"

  git log --color --no-merges --format='%C(auto)%h%d %s %C(black)%C(bold)%cr% C(auto)%an' --author=$author | fzf --no-sort --reverse --tiebreak=index --no-multi \
	--ansi --preview="$viewGitLogLine" \
	--header "enter to view" \
	--bind "enter:execute:$viewGitLogCommit | less -R"
end

function fzum -d "View all unmerged commits across all local branches"
  set viewUnmergedCommits "echo {} | head -1 | xargs -I BRANCH sh -c 'git log master..BRANCH --no-merges --color --format=\"%C(auto)%h - %C(green)%ad%Creset - %s\" --date=format:\'%b %d %Y\''"

  git branch --no-merged master --format "%(refname:short)" | fzf --no-sort --reverse --tiebreak=index --no-multi \
	--ansi --preview="$viewUnmergedCommits"
end

function brn -d "Rename git remote branch"
  git push origin origin/$argv[1]:refs/heads/$argv[2]
  git push origin :$argv[1]
end

function vv -d "Verbose git branch list"
  git branch -vv
end

function fbr -d "View remote branches with fzf"
  git branch -r --color | fzf --ansi
end

function branch_cleanup -d "List branches already merged into master"
  # maybe eventually expand this to do more, like delete selected branches with fzf etc
  git for-each-ref --format='%(authorname) %(color:yellow)->%(color:reset) %(color:green)%(refname:short)%(color:reset)' --sort=authorname --merged=master --color
end

function doh -d "Do a hard git reset"
  git reset --hard
  git clean -fd
end

function ge -d "Open all modified git files in editor"
  git ls-files -moz --exclude-standard | xargs -0 $editor
end

function derp -d "Restore chosen files to their unmodified state"
  set files (file_list)
  if test -n "$files"
	echo $files
	git checkout -- $files
	git status -sb
  else
	echo 'No files chosen'
  end
end

function unmerged_changes -d "View unmerged local branches and the unmerged commits belonging to each"
  set main_branch (get_main_branch)
  git branch --no-merged $main_branch | xargs -I BRANCH sh -c 'printf "\e[1;32m\nBRANCH\e[0m\n"; git cherry -v $main_branch BRANCH' | less -r
end

function clean_local_merged -d "Destroy merged local branches"
  set main_branch (get_main_branch)
  set merged_branches (string split ' ' (git for-each-ref --merged $main_branch --format="%(refname:short)" refs/heads/ | rg -v $main_branch))

  if not test -n "$merged_branches"
	echo 'No dead branches detected in this repository' && return
  end

  echo "Found some merged branches: $merged_branches
  Should we delete them? [Y/n]:"

  switch (read)
  case 'Y' 'y' 'yes' ''
	echo "Deleting local merged branches: $merged_branches"
	git branch -d $merged_branches
  case '*'
	echo "Operation canceled"
  end
end

function clean_remote_merged -d "Destroy merged remote branches"
  set ded_branches (string split ' ' (git for-each-ref --merged master --format="%(refname:lstrip=3)" refs/remotes/origin | rg -v '(^master$|HEAD|^release)'))
  if test -n "$ded_branches"
	git push origin --delete $ded_branches
  else
	echo 'No ded branches detected!'
  end
end

function clone_all_repos -d "Use GH CLI to clone all repos for a given org"
  set -q org[1] || set org "Trust-Will"

  gh repo list $org --limit 50 --json nameWithOwner --jq '.[].nameWithOwner' | xargs -n 1 -P 10 gh repo clone
end

# function to move a git commit from one branch to another, defaulting to the current branch
function git_move_commit -d "Move a git commit from one branch to another" --argument-names 'oops_commit' 'origin_branch' 'destination_branch'
  set -q oops_commit[1] || set oops_commit (git rev-parse HEAD)
  set -q origin_branch[1] || set origin_branch (git rev-parse --abbrev-ref HEAD)
  set -q destination_branch[1] || set destination_branch (git rev-parse --abbrev-ref HEAD)

  git checkout $origin_branch
  git cherry-pick $oops_commit
  git checkout $destination_branch
  git cherry-pick $oops_commit
  git checkout $origin_branch
  git reset --hard HEAD~1
end

function fgf -d "Use fzf as a semi-GUI for git"
  set -l prompt_add "Add > "
  set -l prompt_reset "Reset > "

  set -l git_root_dir (git rev-parse --show-toplevel)
  set -l git_unstaged_files "git ls-files --modified --deleted --other --exclude-standard --deduplicate $git_root_dir"

  set -l git_staged_files "git status --short | grep '^[A-Z]' | awk '{print \$NF}'"

  set -l git_reset "git reset -- {+}"
  set -l enter_cmd "$git_unstaged_files | grep {}; and git add {+}; or $git_reset"

  set -l preview_status_label "[ Status ]"
  set -l preview_status "git status --short"

  set -l header (printf "\
    > CTRL-S to switch between Add Mode and Reset mode
    > CTRL_T for status preview | CTRL-F for diff preview | CTRL-B for blame preview
    > ALT-E to open files in your editor
    > ALT-C to commit | ALT-A to append to the last commit
  ")

  set -l add_header (printf "\
    $header
    > ENTER to add files
    > ALT-P to add patch
  ")

  set -l reset_header (printf "\
    $header
    > ENTER to reset files
    > ALT-D to reset and checkout files
  ")

  set -l mode_reset "change-prompt($prompt_reset)+reload($git_staged_files)+change-header($reset_header)+unbind(alt-p)+rebind(alt-d)"
  set -l mode_add "change-prompt($prompt_add)+reload($git_unstaged_files)+change-header($add_header)+rebind(alt-p)+unbind(alt-d)"

  eval "$git_unstaged_files" | fzf \
    --multi \
    --reverse \
    --no-sort \
    --prompt="Add > " \
    --preview-label="$preview_status_label" \
    --preview="$preview_status" \
    --header "$add_header" \
    --header-first \
    --bind "start:unbind(alt-d)" \
    --bind "ctrl-t:change-preview-label($preview_status_label)" \
    --bind "ctrl-t:+change-preview($preview_status)" \
    --bind "ctrl-f:change-preview-label([ Diff ])" \
    --bind "ctrl-f:+change-preview(
            if git ls-files --others --exclude-standard | grep -qx {};
                echo 'Untracked file!' && bat --color=always {};
            else
                git diff --color-words HEAD -- {} | diff-so-fancy | less -r;
            end
        )" \
    --bind "ctrl-b:change-preview-label([ Blame ])" \
    --bind "ctrl-b:+change-preview(git blame --color-by-age {})" \
    --bind "ctrl-s:transform:(string match --regex '$prompt_add' \$FZF_PROMPT > /dev/null; and echo '$mode_reset'; or echo '$mode_add')" \
    --bind "enter:execute($enter_cmd)" \
    --bind "enter:+reload(string match --regex '$prompt_add' \$FZF_PROMPT > /dev/null; and $git_unstaged_files; or $git_staged_files)" \
    --bind "enter:+refresh-preview" \
    --bind "alt-p:execute(git add --patch {+})" \
    --bind "alt-p:+reload($git_unstaged_files)" \
    --bind "alt-d:execute($git_reset; and git checkout {+})" \
    --bind "alt-d:+reload($git_staged_files)" \
    --bind "alt-c:execute(git commit)+abort" \
    --bind "alt-a:execute(git commit --amend)+abort" \
    --bind "alt-e:execute($EDITOR: {+})" \
    --bind "f1:toggle-header" \
    --bind "f2:toggle-preview" \
    --bind "ctrl-y:preview-up" \
    --bind "ctrl-e:preview-down" \
    --bind "ctrl-u:preview-half-page-up" \
    --bind "ctrl-d:preview-half-page-down"
end

# git ls-files --modified --deleted --other --exclude-standard \
#   --deduplicate (git rev-parse --show-toplevel) \
#   | fzf --multi --reverse --no-sort \
#   --prompt="Add > " \
#   --preview="git status --short" \
#   --bind "ctrl-s:transform:(string match --regex '$prompt_add' \$FZF_PROMPT && echo '$mode_reset' || echo '$mode_add')"


# === TMUX ===
function tmux_all -d "Create / attach to tmux session and create split window running all T&W processes" --argument-names session
  set -q session[1] || set session "tw"

  # see if our session already exists...
  tmux has-session -t $session 2>/dev/null

  # ...and only setup a new split-pane window if it doesn't
  if test ! $status -eq 0
	tmux new-session -ds $session
	tmux select-window -t $session:1
	tmux rename-window 'server-dashboard'
	# create pane splits for our core 4 node apps
	tmux send-keys 'cd $project_path/trust-and-will-api' Enter
	tmux split-window -h
	tmux send-keys 'cd $project_path/trust-and-will-ui' Enter
	tmux split-window -h
	tmux send-keys 'cd $project_path/trust-and-will-advisor-ui' Enter
	tmux split-window -h
	tmux send-keys 'cd $project_path/tw-marketing' Enter
	# make the layout all nice and even
	tmux select-layout tiled
	# fire up all the node scripts at the same time!
	tmux set-window-option synchronize-panes on
	tmux send-keys 'npm run start:dev' Enter
	tmux set-window-option synchronize-panes off
  end

  # now connect to the new setup!
  tmux attach-session -t $session
end

# === Docker ===
function docker_ips -d "Output the IP address of all running containers"
  docker inspect -f '{{.Name}} - {{.NetworkSettings.IPAddress }}' (docker ps -aq)
end
