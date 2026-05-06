-- dxo2photos — AppleScript wrapper for DxO PhotoLab
--
-- The project directory path is stored in Contents/Resources/project_path.txt
-- and written there by build_app.sh. This allows the app to be symlinked
-- (e.g. into /Applications) while all scripts and the Python environment
-- remain in the original project directory.

on projectDir()
    set bundlePath to POSIX path of (path to me)
    set pathFile to bundlePath & "Contents/Resources/project_path.txt"
    return do shell script "cat " & quoted form of pathFile
end projectDir

on open theFiles
    set shellScript to projectDir() & "/dxo2photos.sh"
    set fileArgs to ""
    repeat with f in theFiles
        set fileArgs to fileArgs & " " & quoted form of POSIX path of f
    end repeat
    do shell script shellScript & fileArgs
end open

on run
    set pDir to projectDir()
    set msg to "dxo2photos" & return & return & "Project directory:" & return & pDir & return & return & "Configure this app as an External Program in DxO PhotoLab → Preferences → External Programs."
    display dialog msg buttons {"OK"} default button "OK"
end run
