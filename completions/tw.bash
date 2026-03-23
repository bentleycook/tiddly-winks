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

_tw_workers_for_feature() {
    local feature="$1"
    python3 -c "
import json, yaml, sys, os
feature = sys.argv[1]
sf = os.path.expanduser('~/.tiddly-winks/sessions.json')
try:
    d = json.load(open(sf))
    # Find session matching feature
    session = None
    for k, v in d.items():
        if v.get('feature') == feature or k.endswith('-' + feature):
            session = v
            session_key = k
            break
    if not session:
        sys.exit(0)

    workers = set()
    # Static workers from .tw.yml
    ws = session.get('workspace', '')
    for cfg in ['.tw.yml', '.devenv.yml']:
        p = os.path.join(ws, cfg)
        if os.path.isfile(p):
            try:
                yd = yaml.safe_load(open(p))
                wk = yd.get('workers', {})
                if isinstance(wk, list):
                    workers.update(wk)
                elif isinstance(wk, dict):
                    workers.update(wk.keys())
            except Exception:
                pass
            break

    # Dynamic workers
    for dw in session.get('dynamic_workers', []):
        workers.add(dw.get('name', ''))

    for w in sorted(workers):
        if w:
            print(w)
except Exception:
    pass
" "$feature" 2>/dev/null
}

_tw_subcommands() {
    echo "init start stop list attach status open editor prune claude append"
    echo "spawn workers handoff send tasks patrol feed hook signal setup prime"
    echo "resume reconcile onboard gates daemon config port-owner pane-id doctor nudge help completion"
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
                COMPREPLY=($(compgen -W "--claude --window" -- "$cur"))
            fi
            ;;

        stop|status|workers|feed|open|editor|claude|append|patrol|gates|spawn)
            if [[ $arg_pos -eq 1 ]]; then
                COMPREPLY=($(compgen -W "$(_tw_features)" -- "$cur"))
            elif [[ "$subcmd" == "workers" ]]; then
                # workers takes flags after feature
                COMPREPLY=($(compgen -W "--health --respawn --json --force --cv" -- "$cur"))
            elif [[ "$subcmd" == "feed" ]]; then
                COMPREPLY=($(compgen -W "--problems" -- "$cur"))
            elif [[ "$subcmd" == "stop" ]]; then
                COMPREPLY=($(compgen -W "--done" -- "$cur"))
            elif [[ "$subcmd" == "spawn" && $arg_pos -eq 3 ]]; then
                # Third arg to spawn is optional role
                local roles_dir="$HOME/.claude/roles"
                if [[ -d "$roles_dir" ]]; then
                    COMPREPLY=($(compgen -W "$(ls "$roles_dir" 2>/dev/null | sed 's/\.md$//')" -- "$cur"))
                fi
            fi
            ;;

        # tasks <feature>
        tasks)
            if [[ $arg_pos -eq 1 ]]; then
                COMPREPLY=($(compgen -W "$(_tw_features)" -- "$cur"))
            fi
            ;;

        # send <feature> <worker> "<task>"
        send)
            if [[ $arg_pos -eq 1 ]]; then
                COMPREPLY=($(compgen -W "$(_tw_features)" -- "$cur"))
            elif [[ $arg_pos -eq 2 ]]; then
                # Complete worker names for the selected feature
                local feature="${words[subcmd_idx+1]}"
                COMPREPLY=($(compgen -W "$(_tw_workers_for_feature "$feature")" -- "$cur"))
            fi
            ;;

        # handoff <feature> <worker>
        handoff)
            if [[ $arg_pos -eq 1 ]]; then
                COMPREPLY=($(compgen -W "$(_tw_features)" -- "$cur"))
            elif [[ $arg_pos -eq 2 ]]; then
                local feature="${words[subcmd_idx+1]}"
                COMPREPLY=($(compgen -W "$(_tw_workers_for_feature "$feature")" -- "$cur"))
            fi
            ;;

        # hook {set|clear|show} <feature> <worker>
        hook)
            if [[ $arg_pos -eq 1 ]]; then
                COMPREPLY=($(compgen -W "set clear show" -- "$cur"))
            elif [[ $arg_pos -eq 2 ]]; then
                COMPREPLY=($(compgen -W "$(_tw_features)" -- "$cur"))
            elif [[ $arg_pos -eq 3 ]]; then
                local feature="${words[subcmd_idx+2]}"
                COMPREPLY=($(compgen -W "$(_tw_workers_for_feature "$feature")" -- "$cur"))
            fi
            ;;

        # nudge {enqueue|drain} <session> <worker>
        nudge)
            if [[ $arg_pos -eq 1 ]]; then
                COMPREPLY=($(compgen -W "enqueue drain" -- "$cur"))
            elif [[ $arg_pos -eq 2 ]]; then
                COMPREPLY=($(compgen -W "$(_tw_session_keys)" -- "$cur"))
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
            COMPREPLY=($(compgen -W "--get --set --list" -- "$cur"))
            ;;

        # resume <feature> | --all
        resume)
            if [[ $arg_pos -eq 1 ]]; then
                COMPREPLY=($(compgen -W "--all $(_tw_features)" -- "$cur"))
            fi
            ;;
    esac

    return 0
}

complete -o nosort -F _tw_completions tw
