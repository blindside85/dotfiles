function fish_prompt
    set -l project

    if echo (pwd) | grep -qEi "^/Users/$USER/sites/"
        set  project (echo (pwd) | sed "s#^/Users/$USER/sites/\\([^/]*\\).*#\\1#")
    else
        set  project "Terminal"
    end

    wakatime --write --plugin "fish-wakatime/0.0.1" --entity-type app --project "$project" --entity (echo $history[1] | cut -d ' ' -f1) 2>&1 > /dev/null&
    echo -n '$ '
end
