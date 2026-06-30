# Common aliases for fish shell
# Syntax: alias name 'command'

# ===== Custom/Local =====



# ===== Navigation =====
alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'

# ===== ls variants =====
alias la 'ls -A'

# ===== Safety defaults =====
alias mkdir 'mkdir -p'
alias cp 'cp -i'
alias mv 'mv -i'
alias rm 'rm -i'

# ===== grep =====
alias grep 'grep --color=auto'
alias fgrep 'grep -F --color=auto'
alias egrep 'grep -E --color=auto'

# ===== Git =====
alias gss 'git status'
alias gcm 'git commit -m'
alias ga 'git add'
alias gp 'git push'
alias gpl 'git pull'
alias gbr 'git branch'

# ===== Docker =====
alias dex 'docker exec'
alias dexe 'docker exec -it'
alias dps 'docker ps'
alias drst 'docker restart'
alias drm 'docker rm'
alias dlogs 'docker logs -f'
alias dstop 'docker stop'
alias dstart 'docker start'
alias dpull 'docker pull'
alias dbuild 'docker build'
alias dcomp 'docker compose'
alias dcompup 'docker compose up -d'
alias dcompdown 'docker compose down'
alias dstats 'docker stats'
