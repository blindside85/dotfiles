# set a couple global vars for aliases to use
set editor "code"

# setup custom function commands (same as aliases)
alias fzpv "fzf --preview 'bat --color \"always\" {}'"
alias gph "git push origin HEAD"
alias ip "dig +short myip.opendns.com @resolver1.opendns.com"
# alias cfg "/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME"

function fresh_fish -d "Reload fish to remove need to restart iTerm"
  set -e fish_initialized
  source ~/.config/fish/config.fish
end

function fish_functions -d "Edit my custom fish scripting file"
  eval $editor ~/.config/fish/functions/personal.fish
end

function lli -d "Init - head over to the cms directory"
  cd ~/sites/llb-cms
end

function lls -d "Start Rails server process"
  lli
  bundle exec rails s
end

function llc -d "Start Rails console session"
  lli
  bundle exec rails c
end

function llm -d "Run Rails migration"
  lli
  bundle exec rails db:migrate
end

function llsc -d "Figure out if anything is running on port 3000"
  lsof -wni tcp:3000
end

function llsk -d "Kill all puma processes"
  pkill -9 -f puma
end

function llh -d "Edit hosts file in text editor"
  sudo -S $editor --user-data-dir="~/Library/Application\ Support/Code" /private/etc/hosts
end

function llsshc -d "Edit SSH config in text editor"
  sudo -S $editor ~/.ssh/config
end

function llfish -d "Open fish configs dir"
  eval $editor ~/.config/fish
end

function clear_cap -d "Clear captured output in iTerm"
  printf "\e]1337;ClearCapturedOutput\e\\"
end

function top_10 -d "lists the top 10 used commands in the current cli"
  history | awk '{CMD[$2]++;count++;}END { for (a in CMD)print CMD[a] " " CMD[a]/count*100 "% " a;}' | grep -v "./" | column -c3 -s " " -t | sort -nr | nl |  head -n10
end

function fatties -d "List top X largest directories in the current folder" --argument-names 'count'
  set -q $count or set $count 20
  du -hs * | gsort -hr | head -$count
end

function rentcafe_test -d "Check RentCafe leads for the given data" --argument-names token prop_code user pwd
  curl "https://api.rentcafe.com/rentcafeapi.aspx?requestType=lead&firstName=Jesse&lastName=Test&email=jesse.dupuy@realpage.com&phone=9191283333&source=LeaseLabs&addr1=123%20Main%20Street&city=Corona&state=NY&ZIPCode=11270-8989&apiToken=$token&propertyCode=$prop_code&username=$user&password=$pwd" -H "Content-Type: text/xml; charset=utf-8"
end

function app -d "Switch to app repo and pull fresh"
  echo 'Switching to cms repo and getting latest stuff...'
  lli
  git fetch --all
  git pull -p
end

function pub -d "Switch to public repo and pull fresh"
  echo 'Switching to cms-public repo and getting latest stuff...'
  cd ~/sites/llb-cms%20public
  git fetch --all
  git pull -p
end

function dc -d "Categorize domains by their response codes" --argument-names 'input_file_location' 'output_filename'
  if not test -n "$input_file_location" || not test -n "$output_filename"
    echo "Proper usage: `dc input/file.txt output/file.txt`"
    return
  end
  for domain in (bat $input_file_location)
    echo "Checking $domain..."
    switch (curl -w "%{response_code}" -o /dev/null -s https://{$domain})
    case "200"
      echo " --> Adding $domain to valid domains list"
      echo $domain >> "$output_filename-valid.txt"
    case "301"
      echo " Adding $domain to vanity domains list"
      echo $domain >> "$output_filename-redirects.txt"
    case "000"
      echo " Adding $domain to invalid domains list"
      echo $domain >> "$output_filename-invalid.txt"
    case "*"
      echo " Adding $domain to other domains list"
      echo $domain >> "$output_filename-other.txt"
    end
  end
end

function dip -d "Check IPs of all domains in a list via dig" --argument-names 'input_file_location' 'output_filename'
  if not test -n "$input_file_location" || not test -n "$output_filename"
    echo "Proper usage: `dip input/file.txt output/file.txt`"
    return
  end
  for domain in (bat $input_file_location)
    set dug (dig +short {$domain})
    set subdug (dig +short www.{$domain})
    echo "Digging $domain..."
    echo "$domain, $dug, $subdug" >> $output_filename
  end
end

function durl -d "Check IPs of all domains in a list via curl" --argument-names 'input_file' 'output_file'
  if not test -n "$input_file" || not test -n "$output_file"
    echo "Proper usage: `dip input/file.txt output/file.txt`"
    return
  end
  for domain in (bat $input_file)
    set curl (curl -Isw "\"%{redirect_url}\", \"%{response_code}\"" -o /dev/null http://www.{$domain})
    set curls (curl -Isw "\"%{redirect_url}\", \"%{response_code}\"" -o /dev/null https://www.{$domain})
    echo "Curling $domain..."
    echo "$domain, $curl, $curls" >> $output_file
  end
end

function ego_check -d "Determine a domain's purpose in existence" --argument-names 'input_file' 'output_file'

  for domain in (bat $input_file)
    set orig_domain (string split . $domain)[1]
    set http_domain (string split . (curl -Isw "%{redirect_url}" -o /dev/null http://www.{$domain}))[2]
    set ssl_domain (string split . (curl -Isw "%{redirect_url}" -o /dev/null https://www.{$domain}))[2]
    set http_test (test "$orig_domain" != "$http_domain" && string length -q $http_domain && echo 1 || echo 0)
    set ssl_test (test "$orig_domain" != "$ssl_domain" && string length -q $ssl_domain && echo 1 || echo 0)
    set vanity_domain (test $http_test -eq 1 || test $ssl_test -eq 1 && echo TRUE || echo FALSE)

    echo "Is $domain vain? $vanity_domain"
    echo "$domain, $vanity_domain" >> $output_file
  end
end

function fco -d "Use `fzf` to choose which branch to check out" --argument-names branch
  set -q branch[1]; or set branch ''
  git for-each-ref --format='%(refname:short)' refs/heads | fzf --height 10% --layout=reverse --border --query=$branch --select-1 | xargs git checkout
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

function snag -d "Pick desired files from a chosen branch"
  # use fzf to choose source branch to snag files FROM
  set branch (git for-each-ref --format='%(refname:short)' refs/heads | fzf --height 50% --layout=reverse --border)
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

# based on Edrick's branch refresh instructions whenever we renew qa or pre-release etc
function branch_refresh -d "Remove current copies of branch and refresh with new versions from origin"
  # use fzf to choose source branch to snag files FROM
  set branch (git for-each-ref --format='%(refname:short)' refs/heads | fzf --height 50% --layout=reverse --border)
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

function fssh -d "Fuzzy-find ssh host via ag and ssh into it"
  rg '^host [^*]' ~/.ssh/config | cut -d ' ' -f 2 | fzf | read -l result
  and ssh "$result"
end

function sync -d "Update shared remote branches"
  # Grab the current git branch
  set -l branch (git symbolic-ref -q HEAD | cut -c 12-)

  # Update all testing/production branches
  git fetch --all
  git checkout pre-release
  git pull -p
  git checkout master
  git pull -p

  # Bring you back to where you started
  git checkout $branch
  git pull -p
end

function nb -d "Create new branch based on correct remote" --argument-names branch upstream
  set -q upstream[1]; or set upstream 'origin/master'
  git checkout -t -b $branch $upstream
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

function lldb_old -d "Find live db dump file and replace local db" --argument-names 'user' 'pass'
  # create /tmp and mount to location
  set -q TMP; or set TMP "/tmp"
  set mount_loc (mktemp -d "$TMP/lldb.XXXXXX")
  echo "Mounting Filer resources to `$mount_loc`..."
  mount_smbfs //$user:$pass@192.168.160.21/Data/Technology/database_backups/leaselabs $mount_loc
  wait

  # get most recent pg_dump and use it to refresh local db
  set backup_file (find $mount_loc -name "*.pg_dump" | sort -r | head -n1)
  drop_restore leaselabs_development $backup_file
  wait

  # unmount and remove tmp folder after ops complete
  echo "Db updated with fresh data. Unmounting Filer..."
  umount $mount_loc
  wait
  rm -rf $mount_loc
  echo "Update completed successfully!"
end

function lldb -d "Dump db from RP prod copy, install it locally"
  lli # go to cms dir
  pg_dump --host rcdllbdbpgr001.realpage.com --username cmsadmin --no-password --format=custom cms | pv --rate --bytes --timer > (dump_name)
  wait
  if test -e dump_name
    drop_restore
  end
end

function dump_name -d "Return standard cms db dump name"
  echo cms(date +"%Y%m%d%H%M").pg_dump
end

function drop_restore -d "Drop dev db and restore using new file" --argument-names 'user' 'db' 'dump'
  set -q user[1] || set user leaselabs
  set -q db[1] || set db leaselabs_development
  set -q dump[1] || set dump (dump_name)
  echo "Dropping, creating and restoring db based on $dump"
  dropdb $db
  createdb -O $user $db
  time pg_restore -U $user -d $db -O $dump
end

function brn -d "Rename git remote branch"
  git push origin origin/$argv[1]:refs/heads/$argv[2]
  git push origin :$argv[1]
end

function lldb_last -d "Reports date + time of last db data pull"
  stat -f "%Sm" ~/sites/llb-cms/cms.pg_dump
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

function kill_pid -d "Kill leftover pid file preventing postgres from running"
  set pid_file ~/Library/Application\ Support/Postgres/var-9.4/postmaster.pid
  if test -n "$pid_file"
    rm $pid_file
    echo 'Killed postmaster.pid file, try restarting postgres!'
  else
    echo 'No postmaster.pid file to remove.'
  end
end

function ge -d "Open all modified git files in editor"
  git ls-files -moz --exclude-standard | xargs -0 $editor
end

function fe -d "Open all selected files in editor"
  set files (file_list)
  if test -n "$files"
    eval $editor $files
  else
    echo 'No files chosen'
  end
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

function nv -d "Use fzf to choose files to pass to the editor"
  set files (fzf --multi)
  if test -n "$files"
    eval $editor $files
  else
    echo 'No files chosen for editing...'
  end
end

function sdirect -d "Grab fresh copy of Syndication Direct DS data"
  set project_path ~/sites/data-source-testing
  set output_path {$project_path}/output/syndication_direct

  rm -r {$output_path}/*
  mkdir {$output_path}/floorplans
  curl -o {$output_path}/syndication_direct.xml http://export.mynewplace.com/leaselabs/LeaseLabs_MITS_3.0.xml
  rake -f {$project_path}/Rakefile ds:syndication_direct
  fd . {$output_path}/floorplans | fzf
  open $output_path
end

function reset_abbrs -d "Unset and refresh all fish abbreviations"
  for abbr in (set | rg '^_fish_abbr' | rg '(^\w+).*$' -r '$1')
    set -e $abbr
  end
  set -e fish_initialized
  fresh_fish
end

function unmerged_changes -d "View unmerged local branches and the unmerged commits belonging to each"
  git branch --no-merged master | xargs -I BRANCH sh -c 'printf "\e[1;32m\nBRANCH\e[0m\n"; git cherry -v master BRANCH' | less -r
end

function clean_local_merged -d "View unmerged local branches and the unmerged commits belonging to each"
  git branch --merged master | xargs git branch -d
end

function weigh_in -d "List directories sorted by descending size within current folder"
  # found here: https://serverfault.com/a/62424
  du -d 1 | sort -nr | cut -f2 | sed 's/ /\\ /g' | xargs du -sh
end

function file_list -d "Get list of files for further use in methods"
  # git status -s | fzf --height 20% --layout=reverse --border --multi --ansi | awk '{split($0,a); print a[2]}' | paste -sd' ' -
  git status -s | fzf --height 20% --layout=reverse --border --multi --ansi | awk '{split($0,a); print a[2]}'
end