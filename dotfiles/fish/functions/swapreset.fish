function swapreset
    swapoff -a && &>1 /dev/null && swapon -a
end