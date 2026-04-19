KWIM(1) "kwim" "kwm input manager"

# NAME

kwim - kwm input manager for River Wayland compositor

# SYNOPSIS

*kwim* [OPTION]++
*kwim* *SUBCOMMAND* _DEVICE\_TYPE_ _DEVICE\_OPTION_... [ARG]...

# DESCRIPTION

_kwm_ is a DWM-like dynamic tiling window manager implementing the
river-window-management-v1 protocol.

*kwim* is an input manager separated from _kwm_, implementing the
river-input-management-v1 protocol and/or related protocols in order to
configure input devices independent of window manager.

_kwm_ will automatically run *kwim* at startup. You can also run *kwim* to list
input devices or apply a single rule on demand.

Without any subcommands and options, *kwim* reads input rules from the same
configuration file used by _kwm_.

# OPTIONS

*-h,--help*
	Print a help message and exit.

*-v,--version*
	Print the version and exit.

*-c,--config*
	Specify the configuration file path.

# SUBCOMMANDS

*list*
	Lists all connected devices of the specified type.

*apply*
	Applies configuration rules to a specific device type.

# DEVICE\_TYPE

*input-device*

*libinput-device*

*xbk-keyboard*

# DEVICE\_OPTIONS

## Common Subcommand Options

*-n,--name* _DEVICE\_NAME_
	Input device name

*--regex*
	Enable regex

*--match-null*
	If to match null name

## input-device options

*--repeat-info* _<REPEAT\_INFO>_
	Keyboard repeat info (e.g. 50,300)

*--scroll-factor* _<SCROLL\_FACTOR>_
	Pointer scroll factor

## libinput-device options

*--send-event-modes* _SEND\_EVENT\_MODE\_STATE_
	Set send events mode (enabled, disabled, disabled\_on\_external\_mouse)

*--tap* _TAP\_STATE_
	Set tap to click state (enabled, disabled)

*--drag* _DRAG\_STATE_
	Set tap-and-drag state (enabled, disabled)

*--drag-lock* _DRAG\_LOCK\_STATE_
	Set tap-and-drag lock state (enabled, disabled)

*--tap-button-map* _TAP\_BUTTON\_MAP_
	Set tap button map (left\_right\_middle, left\_middle\_right)

*--three-finger-drag* _THREE\_FINGER\_DRAG\_STATE_
	Set three finger drag state (enabled, disabled)

*--calibration-matrix* _CALIBRATION\_MATRIX_
	Set calibration matrix (format: "a,b,c,d,e,f")

*--accel-profile* _ACCEL\_PROFILE_
	Set acceleration profile (flat, adaptive, custom)

*--accel-speed* _ACCEL\_SPEED_
	Set acceleration speed (-1.0 to 1.0)

*--natural-scroll* _NATURAL\_SCROLL\_STATE_
	Set natural scrolling state (enabled, disabled)

*--left-handed* _LEFT\_HANDED\_STATE_
	Set left-handed mode (enabled, disabled)

*--click-method* _CLICK\_METHOD_
	Set click method (none, button\_areas, clickfinger)

*--clickfinger-button-map* _CLICKFINGER\_BUTTON\_MAP_
	Set clickfinger button map (left\_right\_middle, left\_middle\_right)

*--middle-button-emulation* _MIDDLE\_BUTTON\_EMULATION\_STATE_
	Set middle button emulation (enabled, disabled)

*--scroll-method* _SCROLL\_METHOD_
	Set scroll method (none, two\_finger, edge, on\_button\_down,
	on\_button\_down\_lock)

*--scroll-button* _SCROLL\_BUTTON_
	Set scroll button (e.g., left, right, middle, side, extra, forward, back,
	task)

*--scroll-button-lock* _SCROLL\_BUTTON\_LOCK\_STATE_
	Set scroll button lock state (enabled, disabled)

*--disable-while-typing* _DISABLE\_WHILE\_TYPING\_STATE_
	Set disable-while-typing state (enabled, disabled)

*--disable-while-trackpointing* _DISABLE\_WHILE\_TRACKPOINTING\_STATE_
	Set disable-while-trackpointing state (enabled, disabled)

*--rotation-angle* _ROTATION\_ANGLE_
	Set rotation angle in degrees (0-360)

## xkb-keyboard options

*--numlock* _NUMLOCK\_STATE_
	Set numlock state (enabled, disabled)

*--capslock* _CAPSLOCK\_STATE_
	Set capslock state (enabled, disabled)

*--layout* _KEYBOARD\_LAYOUT_
	Keyboard layout name, index or name

*--keymap-file* _STRING_
	Keymap file (e.g. <file-path>@<format>)

*--keymap-options* _STRING_
	Keymap options (e.g. rules=...,model=...,layout=...,variant=...,options=...)

# CONFIGURATION

By default, kwim reads input rules from the same configuration file used by
_kwm_, in the following paths:

	$XDG_CONFIG_HOME/kwm/config.zon

	$HOME/.config/kwm/config.zon

When user configuration doesn't exists, kwim will try to use the compile time
configuration.

See _kwim(5)_ for all possible settings.

# SEE ALSO

_kwim_(5), _kwm_(1), _river_(1)

# BUGS

https://github.com/kewuaa/kwim/issues
