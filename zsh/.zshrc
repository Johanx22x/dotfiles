#
# ~/.zshrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# ---- PATH (migrado desde .bashrc) ----
# typeset -U evita entradas duplicadas al re-sourcear
typeset -U path PATH
path=("$HOME/.local/bin" $path)
export PATH

# ---- Aliases (migrados desde .bashrc) ----
alias ls='ls --color=auto'
alias grep='grep --color=auto'

# ---- Herramientas modernas (solo si estan instaladas) ----
if command -v eza >/dev/null; then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -l --group-directories-first --icons=auto --git'
  alias la='eza -la --group-directories-first --icons=auto --git'
  alias lt='eza --tree --level=2 --icons=auto'   # arbol rapido
fi

if command -v bat >/dev/null; then
  alias cat='bat --paging=never'   # cat normal, con colores
  alias catp='bat'                 # con pager: buscar con /, salir con q
  export BAT_THEME='ansi'          # respeta los colores del terminal
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# rg = ripgrep (grep rapido, con colores); se deja grep intacto
alias rgi='rg -i'

# ---- fastfetch ----
# neofetch esta archivado desde 2024 y no esta instalado, asi que el
# alias no tapa ningun binario: es memoria muscular, no un reemplazo.
# La config la genera matugen (templates/fastfetch-config.jsonc).
if command -v fastfetch >/dev/null; then
  alias neo='fastfetch'
  alias neofetch='fastfetch'
fi

# ---- Prompt: starship (config en ~/.config/starship.toml) ----
PS1='[%n@%m %1~]%# '   # respaldo, si starship no esta disponible
command -v starship >/dev/null && eval "$(starship init zsh)"

# ---- Historial ----
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS      # no guardar duplicados consecutivos
setopt HIST_IGNORE_SPACE     # ignorar comandos que empiezan con espacio
setopt SHARE_HISTORY         # compartir historial entre sesiones
setopt APPEND_HISTORY

# ---- Autocompletado ----
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # case-insensitive

# ---- Comportamiento ----
setopt AUTO_CD               # escribir un directorio para hacer cd
setopt INTERACTIVE_COMMENTS  # permitir # comentarios en la shell

# ---- Teclas (Home/End/Delete/búsqueda en historial) ----
bindkey -e
bindkey '^[[H'  beginning-of-line
bindkey '^[[F'  end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[A'  history-search-backward
bindkey '^[[B'  history-search-forward

# ---- fzf: busqueda difusa (solo si esta instalado) ----
# Va DESPUES de compinit y de `bindkey -e`: registra completado y remapea
# Ctrl-R, Ctrl-T y Alt-C sobre el keymap emacs. Ninguna choca con las
# teclas de arriba.
#
# `fzf --zsh` es la via oficial desde la 0.48; evita depender de las rutas
# de /usr/share/fzf/, que son cosa del empaquetado de Arch.
if command -v fzf >/dev/null; then
  eval "$(fzf --zsh)"

  # --color=16 fuerza los 16 colores ANSI del terminal en vez de la paleta
  # de 256 que trae fzf. Mismo criterio que BAT_THEME='ansi'.
  export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --color=16'

  # fd como motor: respeta .gitignore y no entra en .git/.
  # Aqui SI se piden los ocultos (al reves que `fd` a secas), porque para
  # elegir una ruta en ~ lo que quieres es justo .config y .local.
  if command -v fd >/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --strip-cwd-prefix --hidden --exclude .git'
  fi
fi

# ---- zoxide: cd que aprende (solo si esta instalado) ----
# Define `z` y `zi`. Sin este eval el binario existe pero `z` no: es una
# funcion de shell, no un ejecutable.
#
# Sin --cmd cd a proposito: reemplazar cd por algo que adivina destinos es
# arriesgado con AUTO_CD activo. `cd` sigue siendo literal.
if command -v zoxide >/dev/null; then
  eval "$(zoxide init zsh)"
fi

# ---- Neovim como reemplazo de vi/vim ----
alias vi='nvim'
alias vim='nvim'
export EDITOR='nvim'
export VISUAL='nvim'

# ---- Saludo al abrir terminal ----
# Va al final para que se imprima despues de todo lo demas. Cuesta ~7ms.
#
# Las dos guardas importan:
#   -o interactive : no dispararlo en shells de scripts.
#   -t 1           : ni cuando la salida esta capturada o redirigida.
#                    Sin esto ensucia cualquier `zsh -ic 'cmd' | ...`
#                    y el logo de kitty se cuela en la tuberia.
if [[ -o interactive && -t 1 ]] && command -v fastfetch >/dev/null; then
  fastfetch
fi
