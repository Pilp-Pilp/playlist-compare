on run argv
    set playlistName to item 1 of argv

    tell application "Music"
        if not (exists playlist playlistName) then
            make new user playlist with properties {name:playlistName}
        end if
    end tell
end run
