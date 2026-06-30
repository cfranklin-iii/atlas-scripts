function fish_greeting
    echo " Logging in to '"(hostname)"' as: $USER..."

    set greetings \
" Loading terminal... Don't fuck anything up :)" \
" Warning: Unauthorized access detected. Just kidding, Welcome back." \
"   ===   Getting ready for some bullshit...   ===   " \
"   ===   Connecting to System Secure Shell...   ===
     ===   Making sure everything is ready...   ===
       ===   Flipping pancakes and bacon...   ===
          ===   Terminal Runtime Loaded.   ==="

    set random_greet $greetings[(math (random 1 (count $greetings)))]
    echo " $random_greet "
end

if status is-interactive; and command -q fastfetch
    fastfetch
end

