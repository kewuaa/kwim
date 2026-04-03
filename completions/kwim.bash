_kwim() {
    local cur prev words cword
    _get_comp_words_by_ref -n : cur prev words cword

    local subcommands="list apply"
    local devices="input-device libinput-device xkb-keyboard"
    local options="-h --help -v --version -c --config"

    local common_options="-h --help --name --regex --match-null"
    local input_device_options="--repeat-info --scroll-factor"
    local libinput_options="--send-event-modes --tap --drag --drag-lock --tap-button-map --three-finger-drag --calibration-matrix --accel-profile --accel-speed --natural-scroll --left-handed --click-method --clickfinger-button-map --middle-button-emulation --scroll-method --scroll-button --scroll-button-lock --disable-while-typing --disable-while-trackpointing --rotation-angle"
    local xkb_options="--numlock --capslock --layout --keymap-file --keymap-options"

    local bool_states="enabled disabled"
    local send_event_modes="enabled disabled disabled_on_external_mouse"
    local tap_button_maps="left_right_middle left_middle_right"
    local accel_profiles="flat adaptive custom"
    local click_methods="none button_areas clickfinger"
    local scroll_methods="none two_finger edge on_button_down on_button_down_lock"
    local buttons="left right middle side extra forward back task"
    local numlock_states="enabled disabled"
    local capslock_states="enabled disabled"

    if [[ "$prev" == "-c" || "$prev" == "--config" ]]; then
        _filedir
        return 0
    fi

    if [[ "$prev" == "--name" ]]; then
        return 0
    fi

    case "$prev" in
        --send-event-modes)
            COMPREPLY=( $(compgen -W "$send_event_modes" -- "$cur") )
            return 0
            ;;
        --tap|--drag|--drag-lock|--three-finger-drag|--natural-scroll|--left-handed|--middle-button-emulation|--scroll-button-lock|--disable-while-typing|--disable-while-trackpointing)
            COMPREPLY=( $(compgen -W "$bool_states" -- "$cur") )
            return 0
            ;;
        --tap-button-map|--clickfinger-button-map)
            COMPREPLY=( $(compgen -W "$tap_button_maps" -- "$cur") )
            return 0
            ;;
        --accel-profile)
            COMPREPLY=( $(compgen -W "$accel_profiles" -- "$cur") )
            return 0
            ;;
        --click-method)
            COMPREPLY=( $(compgen -W "$click_methods" -- "$cur") )
            return 0
            ;;
        --scroll-method)
            COMPREPLY=( $(compgen -W "$scroll_methods" -- "$cur") )
            return 0
            ;;
        --scroll-button)
            COMPREPLY=( $(compgen -W "$buttons" -- "$cur") )
            return 0
            ;;
        --numlock)
            COMPREPLY=( $(compgen -W "$numlock_states" -- "$cur") )
            return 0
            ;;
        --capslock)
            COMPREPLY=( $(compgen -W "$capslock_states" -- "$cur") )
            return 0
            ;;
        --calibration-matrix|--repeat-info|--keymap-file|--keymap-options|--accel-speed|--scroll-factor|--rotation-angle|--layout)
            return 0
            ;;
    esac

    if [[ "$cur" == -* ]]; then
        if [[ ${#words[@]} -eq 2 ]]; then
            COMPREPLY=( $(compgen -W "$options" -- "$cur") )
            return 0
        fi

        if [[ ${#words[@]} -ge 3 ]]; then
            case "${words[1]}" in
                apply)
                    if [[ ${#words[@]} -eq 3 ]]; then
                        COMPREPLY=( $(compgen -W "$devices" -- "$cur") )
                    else
                        case "${words[2]}" in
                            input-device)
                                COMPREPLY=( $(compgen -W "$common_options $input_device_options" -- "$cur") )
                                ;;
                            libinput-device)
                                COMPREPLY=( $(compgen -W "$common_options $libinput_options" -- "$cur") )
                                ;;
                            xkb-keyboard)
                                COMPREPLY=( $(compgen -W "$common_options $xkb_options" -- "$cur") )
                                ;;
                            *)
                                COMPREPLY=( $(compgen -W "$devices" -- "$cur") )
                                ;;
                        esac
                    fi
                    return 0
                    ;;
                list)
                    if [[ ${#words[@]} -eq 3 ]]; then
                        COMPREPLY=( $(compgen -W "$devices" -- "$cur") )
                    else
                        COMPREPLY=( $(compgen -W "-h --help" -- "$cur") )
                    fi
                    return 0
                    ;;
            esac
        fi

        COMPREPLY=( $(compgen -W "$options" -- "$cur") )
        return 0
    fi

    if [[ ${#words[@]} -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "$subcommands" -- "$cur") )
    elif [[ ${#words[@]} -eq 3 ]]; then
        case "${words[1]}" in
            apply|list)
                COMPREPLY=( $(compgen -W "$devices" -- "$cur") )
                ;;
        esac
    elif [[ ${#words[@]} -ge 4 ]]; then
        case "${words[1]}" in
            apply)
                case "${words[2]}" in
                    input-device)
                        COMPREPLY=( $(compgen -W "$common_options $input_device_options" -- "$cur") )
                        ;;
                    libinput-device)
                        COMPREPLY=( $(compgen -W "$common_options $libinput_options" -- "$cur") )
                        ;;
                    xkb-keyboard)
                        COMPREPLY=( $(compgen -W "$common_options $xkb_options" -- "$cur") )
                        ;;
                esac
                ;;
            list)
                COMPREPLY=( $(compgen -W "-h --help" -- "$cur") )
                ;;
        esac
    else
        COMPREPLY=()
    fi
}

complete -F _kwim kwim
