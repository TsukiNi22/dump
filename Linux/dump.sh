#!/bin/bash
# Usage: sudo bash dump.sh
# Interactive menu running the setups of this folder (each one in <setup>/launch.sh)
#
# A loading screen (fixed title, logs below) runs the system update, then everything happens in one fzf window:
# a setup runs in the background, its output is shown live on the right and its questions are asked in the list
# of the window (utils.sh ask_* -> fzf --listen API).
# Internal modes called by fzf (state shared in $DUMP_STATE_DIR):
#   --entries               print the menu entries
#   --header                print the header (keys + running / last setup)
#   --prompt                print the prompt (menu or running)
#   --input                 print the fzf actions of the input line (hidden while a task runs)
#   --preview <n>           details of the entry n + its last / running output
#   --action <n> <f> <q>    enter: run the entry n, or validate a question (<f> = selected items, <q> = query)
#   --escape                esc: cancel a question, or quit
#   --toggle-log            ctrl-l: switch the preview between the end and the whole output
#   --task <n>              run a task (background)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

SELF="$SCRIPT_DIR/dump.sh"
SELF_Q=$(printf '%q' "$SELF")
LOG_TAIL=20 # Lines of output shown under the details (ctrl-l: everything)

# =========================
# State
# =========================
DUMP_STATE_DIR="${DUMP_STATE_DIR:-}"
USB_STATE_FILE="$DUMP_STATE_DIR/usb"
RUNNING_FILE="$DUMP_STATE_DIR/running" # "<pid> <key> <name>" of the running task
MODE_FILE="$DUMP_STATE_DIR/mode"       # menu | answer (a task waits for an answer)

# State file: one key per line, "main:<vendor-id>:<device-id>" or "cancel:<vendor-id>:<device-id>"
# (old format: 4 lines main vendor / device, cancel vendor / device)
# Set MAIN_USBS and CANCEL_USBS ("<vendor-id>:<device-id>,..."), main_usb = the first main key
load_usbs() {
    local line
    local -a old=()

    MAIN_USBS=""
    CANCEL_USBS=""
    if [[ -f "$USB_STATE_FILE" ]]; then
        if grep -q -E '^(main|cancel):' "$USB_STATE_FILE"; then
            while read -r line; do
                case "$line" in
                    main:*) MAIN_USBS+="${MAIN_USBS:+,}${line#main:}" ;;
                    cancel:*) CANCEL_USBS+="${CANCEL_USBS:+,}${line#cancel:}" ;;
                esac
            done < "$USB_STATE_FILE"
        else
            mapfile -t old < "$USB_STATE_FILE"
            [[ -n "${old[0]:-}" && -n "${old[1]:-}" ]] && MAIN_USBS="${old[0]}:${old[1]}"
            [[ -n "${old[2]:-}" && -n "${old[3]:-}" ]] && CANCEL_USBS="${old[2]}:${old[3]}"
        fi
    fi
    return 0
}

# Save MAIN_USBS and CANCEL_USBS
save_usbs() {
    local usb

    {
        for usb in ${MAIN_USBS//,/ }; do echo "main:$usb"; done
        for usb in ${CANCEL_USBS//,/ }; do echo "cancel:$usb"; done
    } > "$USB_STATE_FILE"
}

# Print "<pid> <key> <name>" of the running task (nothing when no task runs)
running_task() {
    local pid

    [[ -f "$RUNNING_FILE" ]] || return 0
    read -r pid _ < "$RUNNING_FILE"
    if kill -0 "$pid" 2> /dev/null; then
        cat "$RUNNING_FILE"
    fi
}

mode() {
    cat "$MODE_FILE" 2> /dev/null || echo "menu"
}

# =========================
# Usb selection
# =========================
# Ask the usb keys of a role one by one, print "<vendor-id>:<device-id>" per line (nothing when none),
# return 1 when cancelled. A key already chosen, or listed in <excluded> (the keys of the other role), isn't proposed
select_usb_list() {
    local header="$1"
    local excluded="$2"
    local -a chosen=()
    local -a choices=()
    local -a keys=()
    local selected=""
    local usb=""
    local vendor_id=""
    local device_id=""
    local line

    while true; do
        choices=()
        while read -r line; do
            usb="${line%% *}"
            if ! usb_in_list "$usb" "$excluded" && ! usb_in_list "$usb" "$(IFS=,; echo "${chosen[*]:-}")"; then
                choices+=("$usb - ${line#* }")
            fi
        done < <(lsusb | awk '{print $6 " " substr($0, index($0, $7))}')
        selected=$(ask_choose "$header (chosen: ${chosen[*]:-none})" "${choices[@]}" "Manual" "Done") || return 1
        case "$selected" in
            "Manual")
                vendor_id=$(ask_input "Usb vendor-id (ex: ffff):") || return 1
                device_id=$(ask_input "Usb device-id (ex: 5678):") || return 1
                usb="$vendor_id:$device_id"
                ;;
            "Done"|"")
                break
                ;;
            *)
                usb="${selected%% *}"
                ;;
        esac
        if [[ ! "$usb" =~ ^[0-9A-Fa-f]{4}:[0-9A-Fa-f]{4}$ ]]; then
            warning "'$usb' is not a vendor-id:device-id"
        elif usb_in_list "$usb" "$excluded"; then
            warning "$usb is already used by the other role: a key can't be a main key and a cancel key"
        elif usb_in_list "$usb" "$(IFS=,; echo "${chosen[*]:-}")"; then
            warning "$usb is already chosen"
        else
            chosen+=("${usb,,}")
        fi
    done
    keys=("${chosen[@]}")
    [[ ${#keys[@]} -gt 0 ]] && printf '%s\n' "${keys[@]}"
    return 0
}

# Print the state of the selected usb keys of a role
check_usbs() {
    local name="$1"
    local list="$2"
    local usb

    if [[ -z "$list" ]]; then
        info "No $name usb set"
        return 0
    fi
    for usb in ${list//,/ }; do
        if lsusb -d "$usb" > /dev/null 2>&1; then
            ok "The $name usb has been found ($usb)"
        else
            failed "Can't find the $name usb ($usb): it is saved but not plugged"
        fi
    done
}

# Ask the main (security) keys then the cancel keys, saved in the state: no key can be in both lists
# Cancelled -> the current keys are kept, return 1
select_usbs() {
    local main
    local cancel

    if ! main=$(select_usb_list "Main usb keys (optional but recommended)" ""); then
        skipped "Usb keys unchanged"
        return 1
    fi
    main=$(paste -sd, <<< "$main")
    if ! cancel=$(select_usb_list "Cancel usb keys (optional, not a main key)" "$main"); then
        skipped "Usb keys unchanged"
        return 1
    fi
    cancel=$(paste -sd, <<< "$cancel")
    MAIN_USBS="$main"
    CANCEL_USBS="$cancel"
    if usbs_overlap "$MAIN_USBS" "$CANCEL_USBS" > /dev/null; then
        failed "A key can't be both a main key and a cancel key"
        return 1
    fi
    check_usbs "main" "$MAIN_USBS"
    check_usbs "cancel" "$CANCEL_USBS"
    save_usbs
}

# =========================
# Tasks
# =========================
task_update() {
    section "UPDATE"
    box_open "UPDATE-PACKAGE"
    if ! pkg_update; then
        box_close "UPDATE-PACKAGE"
        failed "Update package"
        return 1
    fi
    box_close "UPDATE-PACKAGE"
    ok "Update package"
    install_packages gum fzf usbutils less curl
}

task_usb_keys() {
    section "USB-KEYS"
    select_usbs || true
}

# Run a setup script: task_setup <script> [arg...]
task_setup() {
    bash "$@"
}

# Run a setup needing a main usb key: without one plugged, propose to choose them now (or only deactivate)
task_usb_setup() {
    local script="$1"
    local choice

    load_usbs
    if ! usbs_any_plugged "$MAIN_USBS"; then
        choice=$(ask_choose "$TASK_NAME needs a main usb key:" \
            "Choose the usb keys now" "Deactivation only") || choice="Cancel"
        case "$choice" in
            "Choose the usb keys now")
                section "USB-KEYS"
                if ! select_usbs; then
                    skipped "$TASK_NAME (no usb key)"
                    return 0
                fi
                load_usbs
                section "$TASK_NAME"
                ;;
            "Deactivation only")
                info "No usb key: deactivation only"
                ;;
            *)
                skipped "$TASK_NAME (no usb key)"
                return 0
                ;;
        esac
    fi
    bash "$script" "$MAIN_USBS" "$CANCEL_USBS"
}

# =========================
# Menu
# =========================
# Print the menu entries (one per line), they depend on the selected usb
# While a task runs the list is locked: one line, the output is on the right (questions excepted)
menu_entries() {
    local usb_state=""
    local -a task=()

    read -r -a task <<< "$(running_task)" || true
    if [[ ${#task[@]} -gt 0 ]]; then
        echo "${YELLOW}${BOLD}Running: ${task[2]}${RESET} ${GREY}(output on the right)${RESET}"
        return 0
    fi
    local usb_keys="${GREY}(optional, not set)${RESET}"

    load_usbs
    if ! usbs_any_plugged "$MAIN_USBS"; then
        usb_state=" ${YELLOW}(usb key needed)${RESET}"
    fi
    if [[ -n "$MAIN_USBS" ]]; then
        usb_keys="${GREY}(main: $MAIN_USBS, cancel: ${CANCEL_USBS:-none})${RESET}"
    fi
    printf '%s\n' \
        "System Update" \
        "Usb Keys $usb_keys" \
        "Pam Usb$usb_state" \
        "Usb Lock & Power Shutdown$usb_state" \
        "Screen Of Intruder$usb_state" \
        "Dotfile" \
        "Package & App" \
        "Custom Package & Binary" \
        "AI" \
        "N8n" \
        "Git" \
        "Grub & Plymouth" \
        "Quit"
}

# Entry of index <n> (0 = first, index given by fzf)
entry_at() {
    menu_entries | sed -n "$(($1 + 1))p"
}

# Name of the log / status files of an entry ("Pam Usb (usb key needed)" -> Pam_Usb)
entry_key() {
    local name

    name=$(sed 's/\x1b\[[0-9;]*m//g' <<< "$1")
    name="${name%% (*}"

    echo "${name//[^A-Za-z0-9]/_}"
}

# Set TASK_NAME and TASK_CMD (function + arguments) of an entry, return 1 for Quit
entry_task() {
    load_usbs
    case "$1" in
        "System Update") TASK_NAME="SYSTEM-UPDATE"; TASK_CMD=(task_update) ;;
        "Usb Keys"*) TASK_NAME="USB-KEYS"; TASK_CMD=(task_usb_keys) ;;
        "Pam Usb"*) TASK_NAME="PAM-USB"; TASK_CMD=(task_usb_setup "$SCRIPT_DIR/pam_usb/launch.sh") ;;
        "Usb Lock & Power Shutdown"*) TASK_NAME="USB_LOCK-POWER_SHUTDOWN"
            TASK_CMD=(task_usb_setup "$SCRIPT_DIR/usb_lock_and_power_shutdown/launch.sh") ;;
        "Screen Of Intruder"*) TASK_NAME="TAKE-SCREEN-OF-INTRUDER"
            TASK_CMD=(task_usb_setup "$SCRIPT_DIR/take_screen_of_intruder/launch.sh") ;;
        "Dotfile") TASK_NAME="DOTFILE"; TASK_CMD=(task_setup "$SCRIPT_DIR/dotfile/launch.sh") ;;
        "Package & App") TASK_NAME="PACKAGE-APP"; TASK_CMD=(task_setup "$SCRIPT_DIR/package_app/launch.sh") ;;
        "Custom Package & Binary") TASK_NAME="CUSTOM-PACKAGE"; TASK_CMD=(task_setup "$SCRIPT_DIR/custom_package/launch.sh") ;;
        "AI") TASK_NAME="AI"; TASK_CMD=(task_setup "$SCRIPT_DIR/ai/launch.sh") ;;
        "N8n") TASK_NAME="N8N"; TASK_CMD=(task_setup "$SCRIPT_DIR/n8n/launch.sh") ;;
        "Git") TASK_NAME="GIT"; TASK_CMD=(task_setup "$SCRIPT_DIR/git/launch.sh") ;;
        "Grub & Plymouth") TASK_NAME="GRUB-PLYMOUTH"; TASK_CMD=(task_setup "$SCRIPT_DIR/grub_plymouth/launch.sh") ;;
        *) return 1 ;;
    esac
}

# Run a task in the background: everything (questions excepted) goes to <key>.log, the result to <key>.status
run_task() {
    local entry="$1"
    local key
    local status=0

    entry_task "$entry" || return 0
    key=$(entry_key "$entry")
    export DUMP_LOG="$DUMP_STATE_DIR/$key.log"
    echo "$$ $key $TASK_NAME" > "$RUNNING_FILE"
    fzf_post "$MENU_ACTIONS"
    {
        "${TASK_CMD[@]}" || status=1
        echo
        if [[ "$status" -eq 0 ]]; then
            ok "${BOLD}$TASK_NAME${RESET} done"
        else
            failed "$TASK_NAME (see the errors above)"
        fi
    } > "$DUMP_LOG" 2>&1 < /dev/null
    if [[ "$status" -eq 0 ]]; then
        echo "OK $TASK_NAME $(date +%H:%M:%S)" > "$DUMP_STATE_DIR/$key.status"
    else
        echo "FAILED $TASK_NAME $(date +%H:%M:%S)" > "$DUMP_STATE_DIR/$key.status"
    fi
    echo "$key" > "$DUMP_STATE_DIR/last"
    rm -f "$RUNNING_FILE"
    fzf_post "$MENU_ACTIONS+first"
}

# Colored result of a status file: "✔ NAME 12:00:00" / "✘ NAME 12:00:00"
status_line() {
    local result
    local rest

    read -r result rest < "$1"
    if [[ "$result" == "OK" ]]; then
        echo "${GREEN}${BOLD}✔${RESET} $rest"
    else
        echo "${RED}${BOLD}✘${RESET} $rest"
    fi
}

menu_header() {
    local -a task=()
    local last

    read -r -a task <<< "$(running_task)" || true
    echo "${GREY}enter run • ctrl-l output • esc quit${RESET}"
    if [[ ${#task[@]} -gt 0 ]]; then
        echo "${YELLOW}${BOLD}⏳ Running: ${task[2]}${RESET}"
    elif [[ -f "$DUMP_STATE_DIR/last" ]]; then
        last=$(cat "$DUMP_STATE_DIR/last")
        echo "Last: $(status_line "$DUMP_STATE_DIR/$last.status")"
    else
        echo "${GREY}No setup run yet${RESET}"
    fi
}

# Draw a task output at the width of the preview, in the style of describe.sh:
# @@SECTION@@ -> cyan sub-title, @@BOX@@ (command output) -> grey block, [ OK ]... tags -> colored bullets,
# long lines cut with … (no wrap). render_log full|summary (summary: the blocks folded on one line)
render_log() {
    LC_ALL=C.UTF-8 gawk -v width="${RENDER_WIDTH:-${FZF_PREVIEW_COLUMNS:-80}}" -v margin="${RENDER_MARGIN:-}" -v mode="$1" \
        -v cyan="$CYAN" -v grey="$GREY" -v green="$GREEN" -v red="$RED" -v yellow="$YELLOW" -v blue="$BLUE" \
        -v bold="$BOLD" -v reset="$RESET" '
        function cut(text, room) {
            return length(text) > room ? substr(text, 1, room - 1) "…" : text
        }
        function line(text) {
            print margin text
            fflush()
        }
        # The └ of a closed block waits for the next line: a result goes on it (└ ✔ ...)
        function close_box() {
            if (closing)
                line(grey "  └" reset)
            closing = 0
        }
        function result(symbol, text) {
            if (closing)
                line(grey "  └ " reset symbol reset " " cut(text, width - 7))
            else
                line("  " symbol reset " " cut(text, width - 5))
            closing = 0
        }
        {
            gsub(/\033\[[0-9;?]*[A-Za-z]/, "")
            gsub(/\r/, "")
        }
        /^@@SECTION@@ / {
            close_box()
            line("")
            line(cyan bold substr($0, 13) reset)
            next
        }
        /^@@BOX@@ / {
            close_box()
            box = substr($0, 9)
            count = 0
            if (mode == "full")
                line(grey "  ┌ " box reset)
            next
        }
        /^@@BOXEND@@ / {
            if (mode == "full")
                closing = 1
            else
                line(grey "  ▸ " box " (" count " lines, ctrl-l)" reset)
            box = ""
            next
        }
        box != "" {
            count++
            if (mode == "full" && $0 != "")
                line(grey "  │ " reset cut($0, width - 5))
            next
        }
        /^\[  OK  \] / { result(green "✔", substr($0, 10)); next }
        /^\[FAILED\] / { result(red bold "✘", substr($0, 10)); next }
        /^\[ SKIP \] / { result(yellow "–", substr($0, 10)); next }
        /^\[ WARN \] / { result(yellow "⚠", substr($0, 10)); next }
        /^\[ INFO \] / { result(blue "•", substr($0, 10)); next }
        /^$/ { next }
        {
            close_box()
            line("  " cut($0, width - 3))
        }
        END { close_box() }
    '
}

# Title of a task in the describe.sh style ("System_Update" -> System Update)
task_title() {
    local title="${1//_/ }"

    echo "${BOLD}${MAGENTA}$title${RESET}"
    echo "${GREY}$(printf '─%.0s' $(seq 1 ${#title}))${RESET}"
}

# Sub-title of the output: "<label> ─────────"
output_title() {
    local plain

    plain=$(sed 's/\x1b\[[0-9;]*m//g' <<< "$1")
    echo
    echo "$1 ${GREY}$(printf '─%.0s' $(seq 1 $((${FZF_PREVIEW_COLUMNS:-80} - ${#plain} - 2))))${RESET}"
}

# Output of a task: live while it runs (until the task ends), folded or whole (ctrl-l) when finished
show_output() {
    local key="$1"
    local pid="$2"
    local log="$DUMP_STATE_DIR/$key.log"

    [[ -f "$log" ]] || return 0
    if [[ -n "$pid" ]]; then
        tail -n +1 -f --pid="$pid" "$log" | render_log full
    elif [[ -f "$DUMP_STATE_DIR/full_log" ]]; then
        render_log full < "$log"
    else
        render_log summary < "$log"
    fi
}

preview_entry() {
    local entry="$1"
    local key
    local -a task=()

    read -r -a task <<< "$(running_task)" || true
    # A question is asked: output of the task asking it
    if [[ "$(mode)" == "answer" && ${#task[@]} -gt 0 ]]; then
        task_title "${task[1]}"
        output_title "${MAGENTA}${BOLD}❯${RESET} ${BOLD}Waiting for your answer${RESET} ${GREY}(list on the left)${RESET}"
        render_log full < "$DUMP_STATE_DIR/${task[1]}.log"
        return 0
    fi
    # A task runs (list locked): its live output
    if [[ ${#task[@]} -gt 0 ]]; then
        task_title "${task[1]}"
        output_title "${YELLOW}${BOLD}⏳ Running${RESET}"
        show_output "${task[1]}" "${task[0]}"
        return 0
    fi
    key=$(entry_key "$entry")
    bash "$SCRIPT_DIR/describe.sh" "$entry"
    if [[ -f "$DUMP_STATE_DIR/$key.status" ]]; then
        output_title "${BOLD}Last run${RESET} $(status_line "$DUMP_STATE_DIR/$key.status")"
        show_output "$key" ""
    fi
}

# Actions putting the list back (menu, or the locked running line) after a question / a task change
MENU_ACTIONS="reload-sync(bash $SELF_Q --entries)+transform-prompt(bash $SELF_Q --prompt)+transform-header(bash $SELF_Q --header)"
MENU_ACTIONS+="+transform(bash $SELF_Q --input)"
MENU_ACTIONS+="+clear-query+deselect-all+refresh-preview"

# Enter: validate the question, or run the entry
action_enter() {
    local index="$1"
    local selected_file="$2"
    local query="$3"
    local dir="$DUMP_STATE_DIR/ask"
    local entry

    if [[ "$(mode)" == "answer" ]]; then
        case "$(cat "$dir/kind")" in
            choose|multi)
                # Nothing under the cursor (filtered out): wait for a valid choice
                if [[ ! -s "$selected_file" ]]; then
                    echo "ignore"
                    return 0
                fi
                cp "$selected_file" "$dir/answer" ;;
            input) printf '%s\n' "$query" > "$dir/answer" ;;
            write) tr -s ' ' '\n' <<< "$query" > "$dir/answer" ;;
        esac
        echo "menu" > "$MODE_FILE"
        echo "ok" > "$dir/status"
        echo "$MENU_ACTIONS"
        return 0
    fi

    # List locked while a task runs
    if [[ -n "$(running_task)" ]]; then
        echo "ignore"
        return 0
    fi
    entry=$(entry_at "$index")
    if [[ "$entry" == "Quit" ]]; then
        action_escape
        return 0
    fi
    setsid bash "$SELF" --task "$index" > /dev/null 2>&1 < /dev/null &
    echo "refresh-preview"
}

# Esc: cancel the question, or quit (not while a setup runs)
action_escape() {
    if [[ "$(mode)" == "answer" ]]; then
        echo "menu" > "$MODE_FILE"
        echo "cancel" > "$DUMP_STATE_DIR/ask/status"
        echo "$MENU_ACTIONS"
    elif [[ -n "$(running_task)" ]]; then
        echo "transform-header(bash $SELF_Q --header; echo '${RED}A setup is running: quit after its end${RESET}')"
    else
        echo "abort"
    fi
}

# =========================
# Loading screen
# =========================
BANNER=(
    "██╗  ██╗ █████╗ ██████╗ ████████╗ █████╗ ███╗   ██╗██╗ █████╗ "
    "╚██╗██╔╝██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗████╗  ██║██║██╔══██╗"
    " ╚███╔╝ ███████║██████╔╝   ██║   ███████║██╔██╗ ██║██║███████║"
    " ██╔██╗ ██╔══██║██╔══██╗   ██║   ██╔══██║██║╚██╗██║██║██╔══██║"
    "██╔╝ ██╗██║  ██║██║  ██║   ██║   ██║  ██║██║ ╚████║██║██║  ██║"
    "╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝"
)
BANNER_WIDTH=63
LOADING_LOG_WIDTH=90  # Max width of the logs under the title
PRESS_SHADES=(245 244 243 242 241 240 240 241 242 243 244 245 245) # Greys of the "press any key" (light -> dark -> light)
PRESS_SHADE_DELAY=0.12 # Seconds per shade

# Print <text> (display width <width>) centered on <columns>
center_on() {
    printf '%*s%s\n' $((($1 - $2) / 2)) "" "$3"
}

# End of the logs, in their style (bullet line, then a grey "Press any key to continue..."), waits a key
# press_any_key <margin> <result line>
press_any_key() {
    local margin="$1"
    local result="$2"
    local key
    local shade

    # Keys typed during the loading don't count
    while read -rsn 1 -t 0.01 key < /dev/tty; do :; done
    echo "$margin  $result"
    # Light blink: the grey breathes between a few shades (256 colors), rewritten in place until a key
    while true; do
        for shade in "${PRESS_SHADES[@]}"; do
            printf '\r%s  \033[38;5;%sm%s%s' "$margin" "$shade" "Press any key to continue..." "$RESET"
            if read -rsn 1 -t "$PRESS_SHADE_DELAY" key < /dev/tty; then
                return 0
            fi
        done
    done
}

# Fixed centered title at the top, the update logs scroll below it (terminal scroll region)
loading_screen() {
    local columns
    local lines
    local top
    local width
    local log="$DUMP_STATE_DIR/System_Update.log"
    local status=0
    local line
    local subtitle
    local margin

    columns=$(tput cols)
    lines=$(tput lines)
    # The keys typed during the loading aren't shown (restored at the end, or by cleanup on any exit)
    stty -echo -icanon < /dev/tty 2> /dev/null || true
    width=$((columns - 4 < LOADING_LOG_WIDTH ? columns - 4 : LOADING_LOG_WIDTH))
    margin=$(printf '%*s' $(((columns - width) / 2)) "")
    clear
    tput civis
    echo
    for line in "${BANNER[@]}"; do
        center_on "$columns" "$BANNER_WIDTH" "${MAGENTA}${BOLD}$line${RESET}"
    done
    subtitle="Linux dump script ($OS_NAME) - by Tsukini"
    center_on "$columns" "${#subtitle}" "${GREY}$subtitle${RESET}"
    echo
    center_on "$columns" "$width" "${GREY}$(repeat "─" "$width")${RESET}"
    top=$((${#BANNER[@]} + 5))
    printf '\033[%d;%dr' "$((top + 1))" "$lines"
    tput cup "$top" 0

    # The menu needs fzf (+ curl for its API): installed with the update
    # In the background + wait: a signal (kill...) is handled at once, not after the end of the update
    {
        (
            export DUMP_LOG="$log"
            task_update 2>&1
            echo "$?" > "$DUMP_STATE_DIR/update_status"
        ) < /dev/null | tee "$log" | RENDER_WIDTH="$width" RENDER_MARGIN="$margin" render_log full
    } &
    wait "$!" || true
    status=$(cat "$DUMP_STATE_DIR/update_status" 2> /dev/null || echo 1)
    if [[ "$status" -ne 0 ]] || ! command -v fzf > /dev/null; then
        echo "FAILED SYSTEM-UPDATE $(date +%H:%M:%S)" > "$DUMP_STATE_DIR/System_Update.status"
        press_any_key "$margin" "${RED}${BOLD}✘${RESET} Update failed ${GREY}(details in System Update)${RESET}"
    else
        echo "OK SYSTEM-UPDATE $(date +%H:%M:%S)" > "$DUMP_STATE_DIR/System_Update.status"
        press_any_key "$margin" "${GREEN}✔${RESET} Ready"
    fi
    echo "System_Update" > "$DUMP_STATE_DIR/last"
    restore_terminal
    if ! command -v fzf > /dev/null; then
        failed "fzf is missing: the menu can't be opened"
        exit 1
    fi
}

# =========================
# Internal modes (called by fzf)
# =========================
case "${1:-}" in
    --entries) menu_entries; exit 0 ;;
    --header) menu_header; exit 0 ;;
    --prompt)
        if [[ -n "$(running_task)" ]]; then echo "Running ❯ "; else echo "Setup ❯ "; fi
        exit 0 ;;
    --input)
        # No typing while the list is locked (a question shows it again, see utils.sh menu_ask)
        if [[ -n "$(running_task)" ]]; then echo "hide-input+disable-search"; else echo "show-input+enable-search"; fi
        exit 0 ;;
    --preview) preview_entry "$(entry_at "$2")"; exit 0 ;;
    --action) action_enter "$2" "$3" "${4:-}"; exit 0 ;;
    --escape) action_escape; exit 0 ;;
    --toggle-log)
        if [[ -f "$DUMP_STATE_DIR/full_log" ]]; then
            rm -f "$DUMP_STATE_DIR/full_log"
        else
            touch "$DUMP_STATE_DIR/full_log"
        fi
        exit 0 ;;
    --task) run_task "$(entry_at "$2")"; exit 0 ;;
esac

# =========================
# Program
# =========================
DUMP_STATE_DIR=$(mktemp -d)
export DUMP_STATE_DIR
# Put the terminal back as it was: scroll region, cursor, echo / line mode, colors
# (restore_terminal full: also leave the alternate screen of a killed fzf)
restore_terminal() {
    if [[ "${1:-}" == "full" ]]; then
        tput rmcup > /dev/tty 2> /dev/null || true
    fi
    printf '\033[r\033[0m' > /dev/tty 2> /dev/null || true
    tput cnorm > /dev/tty 2> /dev/null || true
    stty sane < /dev/tty 2> /dev/null || true
}

# Kill a process and all its descendants (children first)
kill_tree() {
    local child

    for child in $(pgrep -P "$1"); do
        kill_tree "$child"
    done
    kill "$1" 2> /dev/null || true
}

# Any exit (end, error, ctrl-c, kill, terminal closed): stop the running task (own process group from setsid),
# the loading / fzf still running, remove the state and restore the terminal
cleanup() {
    local pid
    local child

    trap - EXIT INT TERM HUP
    if [[ -f "$DUMP_STATE_DIR/running" ]]; then
        read -r pid _ < "$DUMP_STATE_DIR/running" || true
        kill -- "-$pid" 2> /dev/null || true
    fi
    for child in $(pgrep -P "$$"); do
        kill_tree "$child"
    done
    rm -rf "$DUMP_STATE_DIR"
    restore_terminal full
}
trap cleanup EXIT
# A signal goes through exit -> the EXIT trap runs once (130 = ctrl-c, 143 = kill, 129 = hangup)
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
echo "menu" > "$DUMP_STATE_DIR/mode"

loading_screen
bash "$SELF" --entries | fzf --listen --no-sort --layout=reverse --height=100% --cycle --no-info --multi --ansi \
    --with-shell "bash -c" \
    --border rounded --border-label " 🔻 FEDORA-DUMP 🔻 " --border-label-pos 0:bottom \
    --header "$(bash "$SELF" --header)" --header-first \
    --prompt "Setup ❯ " --pointer "👉" --marker "✔" \
    --preview "bash $SELF_Q --preview {n}" \
    --preview-window "right,60%,wrap-word,follow,border-rounded" --preview-wrap-sign "    " --preview-label " Details & output " \
    --bind "enter:transform(bash $SELF_Q --action {n} {+f} {q})" \
    --bind "esc:transform(bash $SELF_Q --escape)" \
    --bind "ctrl-l:execute-silent(bash $SELF_Q --toggle-log)+refresh-preview" \
    --color "border:6,label:5:bold,preview-border:6,preview-label:6:bold,header:7,prompt:6,pointer:5,marker:5" \
    --color "hl:5,hl+:5,fg+:15:bold,bg+:236" \
    > /dev/null &
# fzf reads its keys on /dev/tty: in the background + wait, a signal is handled at once
wait "$!" || true
clear
echo "👋 Exiting..."
