if status is-interactive
    set -U fish_greeting ""
    fastfetch -c examples/13.jsonc
    eval "$(oh-my-posh init fish --config $HOME/.config/ohmyposh/capr4n.omp.json)"
end
