# Histórico
HISTFILE=~/.histfile
HISTSIZE=50000
SAVEHIST=50000
setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE
setopt AUTO_CD INTERACTIVE_COMMENTS

# Autocomplete: Tab abre menu, com seleção pelas setas.
autoload -Uz compinit
compinit
zmodload zsh/complist
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
bindkey -e
bindkey '^[[A' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward
bindkey '^[[Z' reverse-menu-complete

alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'

# Kubernetes
if (( $+commands[kubectl] )); then
  source <(kubectl completion zsh)
  alias k=kubectl
  compdef k=kubectl
fi
dr="--dry-run=client -o yaml"

# Prompt: Ubuntu, diretório e branch. * indica alterações rastreadas.
autoload -Uz vcs_info add-zsh-hook
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' unstagedstr '*'
zstyle ':vcs_info:git:*' stagedstr '+'
zstyle ':vcs_info:git:*' formats ' %F{magenta}git:(%b)%f%F{yellow}%u%c%f'
zstyle ':vcs_info:git:*' actionformats ' %F{magenta}git:(%b|%a)%f%F{yellow}%u%c%f'
_local_precmd() { vcs_info; }
add-zsh-hook precmd _local_precmd
setopt PROMPT_SUBST
# O ícone requer uma Nerd Font no aplicativo de terminal.
PROMPT=$'╭─ %F{208} Ubuntu%f %F{cyan}%~%f${vcs_info_msg_0_}\n╰─ %(?.%F{green}.%F{red})❯%f '

# Sugestões: seta para a direita aceita o texto em cinza.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# Deve ser carregado por último.
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
