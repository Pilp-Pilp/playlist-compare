on run argv
    set playlistName to item 1 of argv
    set outLines to {}

    -- Jan 1 1970 local time, built via property assignment to avoid locale-dependent date parsing.
    set epoch to current date
    set day of epoch to 1
    set year of epoch to 1970
    set month of epoch to January
    set time of epoch to 0

    tell application "Music"
        set thePlaylist to playlist playlistName
        -- An empty playlist makes Music error on some bulk "every track" properties
        -- (e.g. date added) instead of returning an empty list, so short-circuit here.
        if (count of tracks of thePlaylist) is 0 then
            return ""
        end if

        -- Bulk "of every track" queries resolve as a single Apple Event each, instead of
        -- one Apple Event per track per property via a repeat loop (order of magnitude faster
        -- for large playlists). "as list" guards against AppleScript collapsing a one-track
        -- result to a bare scalar instead of a single-item list.
        set idList to (id of every track of thePlaylist) as list
        set nameList to (name of every track of thePlaylist) as list
        set artistList to (artist of every track of thePlaylist) as list
        set albumList to (album of every track of thePlaylist) as list
        set genreList to (genre of every track of thePlaylist) as list
        set yearList to (year of every track of thePlaylist) as list
        set dateAddedList to (date added of every track of thePlaylist) as list
        set playsList to (played count of every track of thePlaylist) as list
    end tell

    repeat with i from 1 to (count of idList)
        -- Some catalog tracks (e.g. Apple Music streaming tracks) can report "missing value"
        -- for year/plays in a bulk list even though a per-track property access defaults to 0.
        set yearVal to item i of yearList
        if yearVal is missing value then set yearVal to 0
        set playsVal to item i of playsList
        if playsVal is missing value then set playsVal to 0

        set dateAddedVal to item i of dateAddedList
        if dateAddedVal is missing value then
            set dateAddedSecs to "0"
        else
            set dateAddedSecs to (dateAddedVal - epoch) as text
        end if
        set end of outLines to ((item i of idList) as text) & tab & (item i of nameList) & tab & (item i of artistList) & tab & (item i of albumList) & tab & (item i of genreList) & tab & (yearVal as text) & tab & dateAddedSecs & tab & (playsVal as text)
    end repeat

    set AppleScript's text item delimiters to linefeed
    set outText to outLines as text
    set AppleScript's text item delimiters to ""
    return outText
end run
