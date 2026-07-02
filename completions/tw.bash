# tw shell completion — source this file or eval "$(tw completion)"
# Supports bash and zsh (via bashcompinit)

# Enable bash completion in zsh
if [[ -n "$ZSH_VERSION" ]]; then
    autoload -Uz bashcompinit && bashcompinit
fi

_tw_sessions_file="$HOME/.tiddly-winks/sessions.json"

_tw_features() {
    python3 -c "
import json, sys
try:
    d = json.load(open('$_tw_sessions_file'))
    for k, v in d.items():
        f = v.get('feature', k.split('-', 1)[-1] if '-' in k else k)
        if ' ' not in f:
            print(f)
except Exception:
    pass
" 2>/dev/null
}

_tw_session_keys() {
    python3 -c "
import json
try:
    d = json.load(open('$_tw_sessions_file'))
    for k in d:
        if ' ' not in k:
            print(k)
except Exception:
    pass
" 2>/dev/null
}

_tw_subcommands() {
    echo "init start stop done list attach status open editor prune prune-worktrees"
    echo "claude append review setup prime resume reconcile onboard gates config"
    echo "port-owner pane-id doctor help completion"
}

_tw_completions() {
    local cur prev words cword
    if [[ -n "$ZSH_VERSION" ]]; then
        # zsh with bashcompinit
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword=$COMP_CWORD
    else
        _get_comp_words_by_ref cur prev words cword 2>/dev/null || {
            cur="${COMP_WORDS[COMP_CWORD]}"
            prev="${COMP_WORDS[COMP_CWORD-1]}"
            words=("${COMP_WORDS[@]}")
            cword=$COMP_CWORD
        }
    fi

    # Determine the subcommand (first non-option arg after 'tw')
    local subcmd=""
    local subcmd_idx=0
    for ((i=1; i<cword; i++)); do
        if [[ "${words[i]}" != -* ]]; then
            subcmd="${words[i]}"
            subcmd_idx=$i
            break
        fi
    done

    # Position after subcommand (0 = completing subcommand itself)
    local arg_pos=$((cword - subcmd_idx))

    # Completing the subcommand itself
    if [[ -z "$subcmd" || $cword -eq $subcmd_idx ]]; then
        COMPREPLY=($(compgen -W "$(_tw_subcommands)" -- "$cur"))
        return 0
    fi

    case "$subcmd" in
        # Commands that take a feature name as first arg
        attach)
            if [[ $arg_pos -eq 1 ]]; then
                COMPREPLY=($(compgen -W "$(_tw_features) $(_tw_session_keys)" -- "$cur"))
            else
                COMPREPLY=($(compgen -W "--window" -- "$cur"))
            fi
            ;;

        stop|done|status|open|editor|claude|append|gates)
            if [[ $arg_pos -eq 1 ]]; then
                COMPREPLY=($(compgen -W "$(_tw_features)" -- "$cur"))
            elif [[ "$subcmd" == "stop" ]]; then
                COMPREPLY=($(compgen -W "--done" -- "$cur"))
            fi
            ;;

        # review init [--force]
        review)
            if [[ $arg_pos -eq 1 ]]; then
                COMPREPLY=($(compgen -W "init" -- "$cur"))
            else
                COMPREPLY=($(compgen -W "--force" -- "$cur"))
            fi
            ;;

        # start <feature> — no completion needed (new feature name)
        start)
            if [[ $arg_pos -eq 1 ]]; then
                # Suggest existing features for resume, but user can type new ones
                COMPREPLY=($(compgen -W "$(_tw_features)" -- "$cur"))
            elif [[ "$prev" == "--mode" ]]; then
                COMPREPLY=($(compgen -W "local staging" -- "$cur"))
            else
                COMPREPLY=($(compgen -W "--mode --force --attach" -- "$cur"))
            fi
            ;;

        # list
        list)
            COMPREPLY=($(compgen -W "--project --json" -- "$cur"))
            ;;

        # config
        config)
            COMPREPLY=($(compgen -W "show proxy service --get --set --list" -- "$cur"))
            ;;

        # resume <feature> | --all
        resume)
            if [[ $arg_pos -eq 1 ]]; then
                COMPREPLY=($(compgen -W "--all $(_tw_features)" -- "$cur"))
            fi
            ;;

        # setup claude
        setup)
            if [[ $arg_pos -eq 1 ]]; then
                COMPREPLY=($(compgen -W "claude" -- "$cur"))
            fi
            ;;

        # doctor [--fix]
        doctor)
            COMPREPLY=($(compgen -W "--fix" -- "$cur"))
            ;;
    esac

    return 0
}

complete -o nosort -F _tw_completions tw
