source $HOME/.config/fish/conf.d/aliases.fish
set HISTSIZE 1000
set HISTCONTROL ignoreboth

if status is-interactive

    set greetings "Loading terminal... Don't fuck anything up :)"               \
"Warning: Unauthorized access detected. Just kidding, Welcome back."            \
"The only way to learn is to do. Start now."                                    \
"Welcome back, Chronical."                                                      \
"   ===   Welcome back, Chronical.   ==="                                       \
"   ===   Welcome back, Charles.   ==="                                         \
"Getting ready for some bullshit..."                                            \
"   ===   Say Goodbye to shitty Windows! Say Hello to glorious Linux!   ==="    \
"   ===   Connecting to System Secure Shell...   ===
     ===   Making sure everything is ready...   ===
       ===   Flipping pancakes and bacon...   ===
          ===   Terminal Runtime Loaded.   ==="                                \

    set -g fish_greeting $greetings[(math (random 1 (count $greetings)))]

end

exec neofetch || exec fastfetch