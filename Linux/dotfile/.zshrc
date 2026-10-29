# =============================================================================
# ~/.zshrc
#   edit with `edit` (opens it then reloads), reload with `upd`.
#   Sections: Oh My Zsh / PATH / Completions / Lock aliases / Short commands /
#   Git / Make / CMake / Windows (MinGW) / Tools / Navigation / Docker /
#   System / Misc / Network / Functions / Startup / Oh My Zsh options / Zoxide
# =============================================================================


# ===== Oh My Zsh =====
export ZSH="$HOME/.oh-my-zsh"                   # installation path
ZSH_THEME="robbyrussell"                        # theme ("random" picks one, see $RANDOM_THEME)
#plugins=(git)                                  # disabled: the git aliases are mine

fpath=(~/.zsh/completions $fpath)               # must be set before oh-my-zsh (it runs compinit)

# drop the aliases oh-my-zsh could have set, mine are defined below
unalias git 2> /dev/null
unalias mkdir 2> /dev/null

source $ZSH/oh-my-zsh.sh


# ===== PATH & environment =====
export PATH=$HOME/bin:$HOME/.cargo/bin:/opt/gbdk/bin:$PATH
export PATH="$PATH:$HOME/.local/bin"                    # pipx (added 2026-01-13)
export PATH="$HOME/.npm-global/bin:$PATH"                       # npm global bin (Qwen Code installer)
export PATH=$HOME/.opencode/bin:$PATH                   # opencode

export CAPACITOR_ANDROID_STUDIO_PATH=/usr/local/bin/android-studio-flatpak   # js android

#eval "$(thefuck --alias f)"


# ===== Completions =====
# >>> context-forge completion >>>
# Added by context-forge setup.sh (remove this block to disable it)
# /usr/local: install from the sources (cmake), /usr: install from the packages
for _cf_dir in /usr/local/share/zsh/site-functions /usr/share/zsh/site-functions; do
    if [[ -r "$_cf_dir/_context-forge" ]]; then
        (( ${fpath[(Ie)$_cf_dir]} )) || fpath=("$_cf_dir" $fpath)
        _cf_found=1
        break
    fi
done
if (( ${+_cf_found} )); then
    # compinit already done (oh-my-zsh, ...) -> only register the completion
    if (( ${+functions[compdef]} )); then
        autoload -Uz _context-forge && compdef _context-forge context-forge
    else
        autoload -Uz compinit && compinit -i
    fi
fi
unset _cf_dir _cf_found
# <<< context-forge completion <<<



# ===== Zshrc =====
alias edit='v ~/.zshrc && upd'                  # edit then reload
alias upd='source ~/.zshrc'                     # reload

alias dump='\sudo make -C "$HOME/dump"'


# ===== Lock aliases (the bare names lock the session, `tsukini` removes them) =====
alias lock='echo bruh!!!; loginctl lock-session;'

alias sudo='lock'
alias vi='lock'
alias vim='lock'
alias nvim='lock'
alias nano='lock'
alias git='lock'
alias sh='lock'
alias curl='lock'
alias mkdir='lock'
alias ls='\sl'                                  # the real `sl` (steam locomotive) on purpose

alias tsukini='unalias sudo && unalias vi && unalias vim && unalias nvim && unalias nano && unalias git && unalias sh && unalias curl && unalias mkdir && unalias ls && cl'


# ===== Short commands (the real binaries behind the lock aliases) =====
alias s='\sudo'
alias bv='\vi'
alias vm='\vim'
alias v='\nvim'
alias na='\nano'
alias em='\emacs'
alias g='\git'
alias shh='\sh'
alias cur='\curl'
alias mk='\mkdir'
alias sl='\ls -a --color'
alias exi='exit'
alias sv='\sudo nvim'
alias su='\sudo su'


# ===== Git =====
# status / history / diff
alias gst='\git status'
alias gd='\git diff'
alias gl='\git log'

# staging / commit
alias ga='\git add'
alias gcm='\git commit -m'
alias gca='\git commit --amend'
alias gr='\git restore'
alias grm='\git rm'

# branches / tags
alias gck='\git checkout'
alias gsw='\git switch'
alias gb='\git branch'
alias gm='\git merge'
alias gt='\git tag'
alias gc='\git clone'

# remote: current branch (gp / gpl) or a named one (gpb / gplb)
alias gp='\git push'
alias gpl='\git pull'
alias gpb='\git push origin'
alias gplb='\git pull origin'
alias gpbt='\git push origin --tags'
alias kipe_puchinge='\git push origin main --force'

# delete: remote branch / local branch / local tag
alias grmb='\git push origin --delete'
alias grmbl='\git branch -D'
alias grmtl='\git tag -d'

# school shortcuts (stage everything, commit and push)
alias gsetup='\git add --force cmake/; \git add . && \git commit -m "setup commit" && \git push'
alias gcds='\git add . && \git commit -m "fix: coding-style" && \git push'


# ===== Make =====
alias m='make -j $(nproc)'
alias mr='make re -j $(nproc)'
alias mc='make clean'
alias mf='make fclean'
alias md='make d=t -j $(nproc)'                 # debug
alias mrd='make re d=t -j $(nproc)'
alias mo='make d=o -j $(nproc)'                 # optimized
alias mro='make re d=o -j $(nproc)'
alias mgr='make get_unregistered_files'
alias mgk='make get_unknow_files'


# ===== CMake =====
export BUILD_DIR="build"

# configure (build type: none / Test / Debug / Asan / Optimized)
alias build='cmake -S . -B $BUILD_DIR'
alias buildT='cmake -S . -B $BUILD_DIR -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTS=ON'
alias buildD='cmake -S . -B $BUILD_DIR -DCMAKE_BUILD_TYPE=Debug'
alias buildA='cmake -S . -B $BUILD_DIR -DCMAKE_BUILD_TYPE=Asan'
alias buildO='cmake -S . -B $BUILD_DIR -DCMAKE_BUILD_TYPE=Optimized'

# clean
alias cmc='cmake --build $BUILD_DIR --target clean 2> /dev/null'
alias cmf='cmc; rm -rf $BUILD_DIR'              # remove the build dir

# configure + build
alias cmake_no_target='cmake --build $BUILD_DIR --parallel $(nproc)'
alias cm='build && cmake_no_target'
alias cmt='buildT && cmake_no_target'
alias cmd='buildD && cmake_no_target'
alias cma='buildA && cmake_no_target'
alias cmo='buildO && cmake_no_target'

# release / install / packages
alias cmR='build && cmake --build $BUILD_DIR --target release --parallel $(nproc)'
alias cmi='build && s cmake --build $BUILD_DIR --target install --parallel $(nproc)'
alias cmiR='build && s cmake --build $BUILD_DIR --target install_release --parallel $(nproc)'
alias cmpR='build && cmake --build $BUILD_DIR --target package_release --parallel $(nproc)'

# full rebuild (cmf then the alias)
alias cmr='cmf; cm'
alias cmrt='cmf; cmt'
alias cmrd='cmf; cmd'
alias cmra='cmf; cma'
alias cmro='cmf; cmo'
alias cmrR='cmf; cmR'
alias cmri='cmf; cmi'
alias cmriR='cmf; cmiR'
alias cmrpR='cmf; cmpR'

# list the sources not registered in the CMake
alias cmgr='build && cmake --build $BUILD_DIR --target get_unregistered_files'

# release build in a container ($IMAGE) / in the Epitech container
alias cmdoc='docker run -it --rm \
    -u root \
    -v $(pwd):/home/project:Z \
    $IMAGE bash -c "
        apt-get update -qq &&
        apt-get install -y clang cmake make python3 pkg-config &&
        cd /home/project &&
        cmake -S . -B build &&
        cmake --build build --target release --parallel \$(nproc)"
'
alias cmepi='docker run -it --rm \
    -u root \
    -v $(pwd):/home/project:Z \
    epitechcontent/epitest-docker:latest bash -c "
        apt-get update -qq &&
        apt-get install -y clang cmake make python3 pkg-config &&
        cd /home/project &&
        cmake -S . -B build &&
        cmake --build build --target release --parallel \$(nproc)"
'

# tests
alias ctb='ctest --test-dir $BUILD_DIR'

# quick check that the project builds in Release (build dir removed before and after)
alias t='rm -rf build; \mkdir build && cd build && cmake .. -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release && cmake --build . && cd ..; rm -rf build'


# ===== Windows (MinGW-w64 cross compilation) =====
export BUILD_DIR_W=build-windows
export WINEPATH=/usr/x86_64-w64-mingw32/sys-root/mingw/bin   # DLLs for wine
_WTC='-DCMAKE_TOOLCHAIN_FILE=cmake/toolchain/mingw-w64.cmake'

# configure
alias buildW='cmake -S . -B $BUILD_DIR_W $_WTC'
alias buildDW='cmake -S . -B $BUILD_DIR_W $_WTC -DCMAKE_BUILD_TYPE=Debug'
alias buildOW='cmake -S . -B $BUILD_DIR_W $_WTC -DCMAKE_BUILD_TYPE=Optimized'
alias buildTW='cmake -S . -B $BUILD_DIR_W $_WTC -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTS=ON'

# configure + build
alias cmake_no_target_w='cmake --build $BUILD_DIR_W --parallel $(nproc)'
alias cmw='buildW && cmake_no_target_w'
alias cmdw='buildDW && cmake_no_target_w'
alias cmow='buildOW && cmake_no_target_w'
alias cmtw='buildTW && cmake_no_target_w'
alias cmRw='buildW && cmake --build $BUILD_DIR_W --target release --parallel $(nproc)'
alias cmpRw='buildW && cmake --build $BUILD_DIR_W --target package_release --parallel $(nproc)'

# clean / full rebuild
alias cmcw='cmake --build $BUILD_DIR_W --target clean 2> /dev/null'
alias cmfw='cmcw; rm -rf $BUILD_DIR_W'
alias cmrw='cmfw; cmw'
alias cmrdw='cmfw; cmdw'
alias cmrow='cmfw; cmow'
alias cmrtw='cmfw; cmtw'
alias cmrRw='cmfw; cmRw'
alias cmrpRw='cmfw; cmpRw'

# tests under wine
alias ctbw='ctest --test-dir $BUILD_DIR_W'
# run a Windows exe under wine: runw ./r-type_server.exe --help
alias runw='wine'


# ===== Tools =====
# coding style / valgrind
alias cds='mf; coding-style . . && echo "-------------------------------------------------" && cat coding-style-reports.log && rm -f coding-style-reports.log'   # missing: coding-style
alias vg='valgrind --leak-check=full --track-origins=yes --show-leak-kinds=all --errors-for-leak-kinds=all'
alias vgr='vg 2> vg'                            # valgrind output in ./vg
alias rvg='rm -f vg'

# temporary files
alias rmtmp='find . \( -name "*.sw*" -o -name "#*#" -o -name "*~" \) -delete'
alias tmp='\vi tmp_vi_file && rm -f tmp_vi_file'
alias vt='v tmp_file && rm -f tmp_file'

# search (usage: findc <pattern>, searches in .)
alias findfunc='grep -rnE . --include="*.h" --include="*.hpp" -e'
alias findc='grep -rnE . --include="*.c" -e'
alias findh='grep -rnE . --include="*.h" -e'
alias findcpp='grep -rnE . --include="*.cpp" -e'
alias findhpp='grep -rnE . --include="*.hpp" -e'
alias finda='grep -rnE . --include="*" -e'
unalias findx 2> /dev/null                      # the old alias would hijack the definition on a reload
findx() {                                       # usage: findx <glob> <pattern>, ex: findx "*.py" main
    grep -rnE "${2:?usage: findx <glob> <pattern>}" --include="${1:?usage: findx <glob> <pattern>}" .
}

# count lines
alias nbla='find . -type f ! -path "*/.*" -exec wc -l {} +'
alias nblp='find . -type f -name "*.py" -exec wc -l {} +'
alias nblc='find . -type f \( -name "*.c" -o -name "*.h" \) -exec wc -l {} +'
alias nblcpp='find . -type f \( -name "*.cpp" -o -name "*.hpp" \) -exec wc -l {} +'

# python
alias py='python3'
alias p='python3'
alias pex='python3 main.py'
alias rmpc='rm -rf $(find . -name "__pycache__")'

# tmux
alias tm='tmux'
alias tmnh='tmux split-window -h'
alias tmnv='tmux split-window -v'
alias setup_terminal='tmnh && tmux select-pane -L && tmnv && cd include && cl && tmux select-pane -R && tmux select-pane -R  && tmux send-keys "mf && cl && gpl && gst" C-m && tmux select-pane -R && tmux send-keys "cd src && cl && tree" C-m'

# security
alias ssh2john='~/john/run/ssh2john.py'        # missing: ~/john/run/ssh2john.py
alias exegol='\sudo -E $HOME/.local/bin/exegol' # missing: ~/.local/bin/exegol
alias linpeas='\curl -L https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh | \sh'

alias streamlit="~/.local/bin/streamlit"       # missing: ~/.local/bin/streamlit


# ===== Navigation & display =====
alias cd='z'                                    # zoxide
alias cs='cd src/'
alias clb='cd lib/my/'
alias cdd='cd ~/delivery/'
alias cddt='cd ~/delivery/template'             # missing: ~/delivery/template
alias cdp='cd ~/personal_delivery/'

#alias cl="clear && figlet \"I'm  a  FUCKING  banana ! ! !\" && \ls -a --color"
#alias ct="clear && figlet \"I'm  a  FUCKING  banana ! ! !\" && tree"
alias cl="clear && fastfetch && \ls -a --color"
alias ct="clear && fastfetch && tree"
alias fastfetch="~/.config/fastfetch/rdm_img.sh"   # random image


# ===== Docker =====
alias doc='docker run -it --rm -v $(pwd):/home/project:Z -w /home/project ubuntu:24.04 bash'
alias docc='docker run -it --rm -v $(pwd):/home/project:Z -w /home/project $IMAGE bash'
alias epi='docker run -it --rm -v $(pwd):/home/project:Z -w /home/project epitechcontent/epitest-docker:latest bash'
alias psdoc='docker ps -a'
alias stopdoc='docker container prune -f'
alias docker-compose-reup='docker-compose down -v && docker-compose up --build'


# ===== System =====
alias update='\sudo dnf update -y'
alias dnfi='\sudo dnf install'
alias dnfr='\sudo dnf remove'
alias pw='upower -i $(upower -e | grep battery) | grep "percentage" | awk "{print \$2}"'   # battery percentage
alias lum='\sudo vim /sys/class/backlight/intel_backlight/brightness'
alias ulimit_reset='ulimit -s 8192'


# ===== School =====
alias h='cd ~/delivery/year_1/B-MUL-100-BDX-1-1-myhunter-mathias.dumoulin/ && ./my_hunter -l 3 -d 2. && cd -'
alias hd='cd ~/delivery/year_1/B-MUL-100-BDX-1-1-myhunter-mathias.dumoulin/ && ./my_hunter -l 3 -d 2. -D && cd -'
# corewar: compare our asm with the real one on $FILE
alias tt="rm -f *.cor ; echo 'COMPILATION:' && m && echo && echo 'FILE:' && cat \$FILE && echo && echo 'OUR:' && ./asm \$FILE && mv *.cor our && hexdump -C our && echo && echo 'OTHER:' && ./binaries/asm/asm \$FILE && mv *.cor real && hexdump -C real && echo && echo 'DIFF:' && cmp -l our real | awk '{printf \"Diff at byte %d\n\", \$1 - 2192}' ; rm -f our real"


# ===== Misc =====
alias a='ani-cli'                               # missing: ani-cli
alias e='xeyes'                                 # missing: xeyes
alias rtfm='zenity --info --title="Just" --width=700 --height=400 --text="<span font='\''75'\'' color='\''red'\''><b>RTFM</b></span>\n\n<span font='\''20'\''>READ THE F***ING MANUAL!!!</span>"'
alias lost='zenity --info --title="Just" --width=700 --height=400 --text="<span font='\''75'\'' color='\''red'\''><b>DEVINE QUOI</b></span>\n\n<span font='\''20'\''>j'\''ai perdu!</span>"'
alias morse="bash | sed 's/[aA]/._ /g;s/[bB]/_... /g;s/[cC]/_._. /g;s/[dD]/_.. /g;s/[eE]/. /g;s/[fF]/.._. /g;s/[gG]/__. /g;s/[hH]/.... /g;s/[iI]/.. /g; s/[jJ]/.___ /g;s/[kK]/_._ /g;s/[lL]/._.. /g;s/[mM]/__ /g;s/[nN]/_. /g;s/[oO]/___ /g;s/[pP]/.__. /g;s/[qQ]/__._ /g;s/[rR]/._. /g;s/[sS]/... /g;s/[tT]/_ /g;s/[uU]/.._ /g;s/[vV]/..._ /g;s/[wW]/.__ /g;s/[xX]/_.._ /g;s/[yY]/_.__ /g;s/[zZ]/__.. /g'"
alias tg='echo "_ ._  __. . .._ ._.. ." && play -n synth 0.9 sine 800 >/dev/null 2>&1; sleep 0.3; \
    play -n synth 0.3 sine 800 >/dev/null 2>&1; sleep 0.3; \
    play -n synth 0.1 sine 800 >/dev/null 2>&1; sleep 0.1; \
    play -n synth 0.3 sine 800 >/dev/null 2>&1; sleep 0.3; \
    play -n synth 0.3 sine 800 >/dev/null 2>&1; sleep 0.1; \
    play -n synth 0.3 sine 800 >/dev/null 2>&1; sleep 0.1; \
    play -n synth 0.1 sine 800 >/dev/null 2>&1; sleep 0.3; \
    play -n synth 0.1 sine 800 >/dev/null 2>&1; sleep 0.3; \
    play -n synth 0.1 sine 800 >/dev/null 2>&1; sleep 0.1; \
    play -n synth 0.1 sine 800 >/dev/null 2>&1; sleep 0.1; \
    play -n synth 0.3 sine 800 >/dev/null 2>&1; sleep 0.3; \
    play -n synth 0.1 sine 800 >/dev/null 2>&1; sleep 0.1; \
    play -n synth 0.3 sine 800 >/dev/null 2>&1; sleep 0.1; \
    play -n synth 0.1 sine 800 >/dev/null 2>&1; sleep 0.1; \
    play -n synth 0.1 sine 800 >/dev/null 2>&1; sleep 0.3; \
    play -n synth 0.1 sine 800 >/dev/null 2>&1
'                                               # missing: play (sox)


# ===== Network =====
alias ip_pub='\curl ipinfo.io/ip'

# share the ethernet connection ($ETHERNET, enp3s0 or enp4s0) through wlo1
alias init_ethernet_share=' \
    \sudo iptables -t nat -A POSTROUTING -o wlo1 -j MASQUERADE; \
    \sudo iptables -A FORWARD -i $ETHERNET -o wlo1 -j ACCEPT; \
    \sudo iptables -A FORWARD -i wlo1 -o $ETHERNET -m state --state RELATED,ESTABLISHED -j ACCEPT;
'
alias init_ethernet_share3=' \
    \sudo iptables -t nat -A POSTROUTING -o wlo1 -j MASQUERADE; \
    \sudo iptables -A FORWARD -i enp3s0 -o wlo1 -j ACCEPT; \
    \sudo iptables -A FORWARD -i wlo1 -o enp3s0 -m state --state RELATED,ESTABLISHED -j ACCEPT;
'
alias init_ethernet_share4=' \
    \sudo iptables -t nat -A POSTROUTING -o wlo1 -j MASQUERADE; \
    \sudo iptables -A FORWARD -i enp4s0 -o wlo1 -j ACCEPT; \
    \sudo iptables -A FORWARD -i wlo1 -o enp4s0 -m state --state RELATED,ESTABLISHED -j ACCEPT;
'

# static address of the shared link (see the values below)
alias force_ip=' \
    \sudo ip addr add 192.168.50.1/24 dev $ETHERNET; \
    \sudo ip link set $ETHERNET up;
'
alias force_ip3=' \
    \sudo ip addr add 192.168.50.1/24 dev enp3s0; \
    \sudo ip link set enp3s0 up;
'
alias force_ip4=' \
    \sudo ip addr add 192.168.50.1/24 dev enp4s0; \
    \sudo ip link set enp4s0 up;
'
# adress ip: 192.168.50.2
# masque: 255.255.255.0
# passerelle: 192.168.50.1
# DNS-1: 1.1.1.1
# DNS-2: 8.8.4.4


# ===== Functions =====
# ollama-hosted [-run|-stop] [ollama args]: open the ssh tunnel to ai-server, run ollama on it, close the tunnel
ollama-hosted() {
    local action="-run"

    if [[ "$1" == "-run" || "$1" == "-stop" ]]; then
        action="$1"
        shift
    fi

    local ssh_pid
    if [[ "$action" == "-stop" ]]; then
        ssh_pid=$(pgrep -n -f 'ssh -N -f ai-server')
        if [[ -n "$ssh_pid" ]]; then
            kill "$ssh_pid"
            echo "Ollama SSH stopped (PID $ssh_pid)"
        else
            echo "No Ollama SSH found"
        fi

        return 0
    fi

    ssh -N -f ai-server
    ssh_pid=$(pgrep -n -f 'ssh -N -f ai-server')

    OLLAMA_HOST=http://127.0.0.1:11435 ollama "$@"
    local exit_code=$?

    kill "$ssh_pid" 2>/dev/null
    return $exit_code
}


# ===== Startup =====
#lost
clear
fastfetch
sl


# ===== Oh My Zsh options (reference) =====
# All disabled by default. To enable one, uncomment it AND move it above `source $ZSH/oh-my-zsh.sh`.
#
# Theme
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )   # themes picked when ZSH_THEME="random" (empty array: all of $ZSH/themes/)
#
# Completion
# CASE_SENSITIVE="true"                         # case-sensitive completion
# HYPHEN_INSENSITIVE="true"                     # _ and - interchangeable (needs CASE_SENSITIVE off)
# COMPLETION_WAITING_DOTS="true"                # red dots while waiting for a completion (or a string such as "%F{yellow}waiting...%f"); can break multiline prompts in zsh < 5.7.1
# ENABLE_CORRECTION="true"                      # command auto-correction
#
# Auto update
# zstyle ':omz:update' mode disabled            # disable automatic updates
# zstyle ':omz:update' mode auto                # update without asking
# zstyle ':omz:update' mode reminder            # only remind when it is time
# zstyle ':omz:update' frequency 13             # check every N days
#
# Terminal / display
# DISABLE_MAGIC_FUNCTIONS="true"                # fix pasting of URLs and other text
# DISABLE_LS_COLORS="true"                      # no colors in ls
# DISABLE_AUTO_TITLE="true"                     # no automatic terminal title
# DISABLE_UNTRACKED_FILES_DIRTY="true"          # faster VCS status on big repositories
# HIST_STAMPS="yyyy-mm-dd"                      # history time stamps: "mm/dd/yyyy" | "dd.mm.yyyy" | "yyyy-mm-dd" | strftime format
#
# Folders / plugins
# ZSH_CUSTOM=/path/to/new-custom-folder         # custom folder instead of $ZSH/custom (plugins/, aliases in *.zsh)
# plugins=(rails git textmate ruby lighthouse)  # plugins of $ZSH/plugins/ or $ZSH_CUSTOM/plugins/ (too many slow the startup)
#
# User configuration
# export MANPATH="/usr/local/man:$MANPATH"
# export LANG=en_US.UTF-8                       # language environment
# export ARCHFLAGS="-arch $(uname -m)"          # compilation flags
# if [[ -n $SSH_CONNECTION ]]; then export EDITOR='vim'; else export EDITOR='nvim'; fi   # editor for remote / local sessions
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"


# ===== imggen: local image generation (FLUX.2 klein 4B, stable-diffusion.cpp) =====
export IMGGEN_DIR="$HOME/personal_delivery/miscellaneous/sd-cpp"   # sd-cpp folder (src/, models/, out/)

imggen() {   # imggen [-f icon|thumb|WxH] [-s seed] [-n count] [-i img] [-r img] [-t strength] [-o name] "prompt"
    local -a o_f o_s o_n o_i o_r o_t o_o o_h
    zparseopts -D -E -F -- f:=o_f s:=o_s n:=o_n i:=o_i r+:=o_r t:=o_t o:=o_o h=o_h || return 1
    if [[ -n $o_h || $# -eq 0 ]]; then
        cat <<'EOF'
imggen [options] "prompt"
  -f FORMAT    icon (512x512, default) | thumb (1280x720, 16:9) | WxH (ex: 768x768)
  -s SEED      first seed (default: random)
  -n COUNT     number of variants, seeds SEED..SEED+COUNT-1 (default: 1)
  -i IMAGE     start from this image (img2img)
  -t STRENGTH  img2img change 0..1 (default: 0.6 with -i)
  -r IMAGE     reference image for editing (repeatable)
  -o NAME      output name, files are NAME_SEED.png (default: date and time)
output: $IMGGEN_DIR/out/   (~2 min per 512x512 image on the RTX 3050)
ex: imggen -f thumb -n 4 "dark king on a throne, purple flames, Roblox blocky character"
    imggen -i out/king_1.png -t 0.4 "same king, red flames"
EOF
        return 0
    fi

    local prompt="$*" fmt="${o_f[2]:-icon}" w h seed count name out
    case $fmt in
        icon)      w=512;  h=512 ;;
        thumb)     w=1280; h=720 ;;
        <->x<->)   w=${fmt%x*}; h=${fmt#*x} ;;
        *)         print -u2 "imggen: unknown format '$fmt' (icon, thumb or WxH)"; return 1 ;;
    esac
    seed=${o_s[2]:-$((RANDOM * 32768 + RANDOM))}
    count=${o_n[2]:-1}
    name=${o_o[2]:-$(date +%Y%m%d-%H%M%S)}
    out="$IMGGEN_DIR/out"

    command mkdir -p "$out"
    local tmp="$out/.in"; command mkdir -p "$tmp"

    # inputs are shrunk first: a 1920x1080 image does not fit the VAE encoder in 4 GB of VRAM
    local ref_max=${IMGGEN_REF_MAX:-768} f
    local -a extra
    if [[ -n ${o_i[2]} ]]; then
        f="$tmp/init.png"; command magick "${o_i[2]}" -resize "${w}x${h}>" "$f" || return 1
        extra+=(-i "$f" --strength "${o_t[2]:-0.6}")
    fi
    local r n=0
    for r in "${(@)o_r:#-r}"; do
        f="$tmp/ref$((n++)).png"; command magick "$r" -resize "${ref_max}x${ref_max}>" "$f" || return 1
        extra+=(-r "$f")
    done

    # the NVIDIA Vulkan driver is not installed on the host (no xorg-x11-drv-nvidia): use the one of the flatpak runtime,
    # so sd-cli runs on the RTX 3050 and not on the Intel iGPU (which hangs and eats the RAM)
    local nv=(/var/lib/flatpak/runtime/org.freedesktop.Platform.GL.nvidia-*/x86_64/*/*/files(N[-1]))
    if [[ -z $nv ]]; then print -u2 "imggen: NVIDIA Vulkan driver not found (flatpak runtime org.freedesktop.Platform.GL.nvidia-*)"; return 1; fi

    local k s rc
    for ((k = 0; k < count; k++)); do
        s=$((seed + k))
        print "imggen: ${name}_${s} (${w}x${h}) ..."
        VK_DRIVER_FILES="$nv/vulkan/icd.d/nvidia_icd.json" LD_LIBRARY_PATH="$nv/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
        command nice -n 10 "$IMGGEN_DIR/src/build/bin/sd-cli" \
            --diffusion-model "$IMGGEN_DIR/models/flux-2-klein-4b-Q4_0.gguf" \
            --vae "$IMGGEN_DIR/models/flux2-vae.safetensors" \
            --llm "$IMGGEN_DIR/models/Qwen3-4B-Q4_K_M.gguf" \
            --cfg-scale 1.0 --steps 4 --offload-to-cpu \
            -W $w -H $h -s $s -p "$prompt" "${extra[@]}" \
            -o "$out/${name}_${s}.png" 2>&1 | command grep -E "^\[E\]|completed in|saved"
        rc=${pipestatus[1]}
        if [[ $rc -ne 0 || ! -f "$out/${name}_${s}.png" ]]; then
            print -u2 "imggen: failed (${name}_${s})"; return 1
        fi
        print "  -> $out/${name}_${s}.png"
    done
}

# ===== Zoxide (keep it the LAST thing of this file, or zoxide warns at each command) =====
eval "$(zoxide init zsh)"

# >>> tsukini-skills completion >>>
# Added by the skills setup.sh (remove this block to disable it): completion of claude-cluster xstyle
_ts_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"
(( ${fpath[(Ie)$_ts_dir]} )) || fpath=("$_ts_dir" $fpath)
if (( ${+functions[compdef]} )); then
    # compinit already done (oh-my-zsh, ...) -> only register the completions
    for _ts_tool in claude-cluster xstyle; do
        autoload -Uz "_$_ts_tool" && compdef "_$_ts_tool" "$_ts_tool"
    done
else
    autoload -Uz compinit && compinit -i
fi
unset _ts_dir _ts_tool
# <<< tsukini-skills completion <<<
