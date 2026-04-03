#compdef kwim

_kwim() {
    local -a subcommands devices
    local -a common_options input_device_options libinput_options xkb_options

    subcommands=(
        'list'
        'apply'
    )

    devices=(
        'input-device'
        'libinput-device'
        'xkb-keyboard'
    )

    common_options=(
        '--name'
        '--regex'
        '--match-null'
    )

    input_device_options=(
        '--repeat-info'
        '--scroll-factor'
    )

    libinput_options=(
        '--send-event-modes'
        '--tap'
        '--drag'
        '--drag-lock'
        '--tap-button-map'
        '--three-finger-drag'
        '--calibration-matrix'
        '--accel-profile'
        '--accel-speed'
        '--natural-scroll'
        '--left-handed'
        '--click-method'
        '--clickfinger-button-map'
        '--middle-button-emulation'
        '--scroll-method'
        '--scroll-button'
        '--scroll-button-lock'
        '--disable-while-typing'
        '--disable-while-trackpointing'
        '--rotation-angle'
    )

    xkb_options=(
        '--numlock'
        '--capslock'
        '--layout'
        '--keymap-file'
        '--keymap-options'
    )

    case $words[$CURRENT-1] in
        --send-event-modes)
            compadd enabled disabled disabled_on_external_mouse
            return
            ;;
        --tap|--drag|--drag-lock|--three-finger-drag|--natural-scroll|--left-handed|--middle-button-emulation|--scroll-button-lock|--disable-while-typing|--disable-while-trackpointing)
            compadd enabled disabled
            return
            ;;
        --tap-button-map|--clickfinger-button-map)
            compadd left_right_middle left_middle_right
            return
            ;;
        --accel-profile)
            compadd flat adaptive custom
            return
            ;;
        --click-method)
            compadd none button_areas clickfinger
            return
            ;;
        --scroll-method)
            compadd none two_finger edge on_button_down on_button_down_lock
            return
            ;;
        --scroll-button)
            compadd left right middle side extra forward back task
            return
            ;;
        --numlock|--capslock)
            compadd enabled disabled
            return
            ;;
        -c|--config|--keymap-file)
            _files
            return
            ;;
        --name|--repeat-info|--calibration-matrix|--accel-speed|--scroll-factor|--rotation-angle|--layout|--keymap-options)
            return
            ;;
    esac

    if [[ $CURRENT -eq 2 ]]; then
        compadd -a subcommands
    elif [[ $CURRENT -eq 3 ]]; then
        compadd -a devices
    elif [[ $CURRENT -ge 4 ]]; then
        local subcommand=$words[2]
        local device_type=$words[3]

        case $subcommand in
            list)
                compadd -- -h --help
                ;;
            apply)
                case $device_type in
                    input-device)
                        compadd -a common_options
                        compadd -a input_device_options
                        ;;
                    libinput-device)
                        compadd -a common_options
                        compadd -a libinput_options
                        ;;
                    xkb-keyboard)
                        compadd -a common_options
                        compadd -a xkb_options
                        ;;
                esac
                ;;
        esac
    fi
}

_kwim "$@"
