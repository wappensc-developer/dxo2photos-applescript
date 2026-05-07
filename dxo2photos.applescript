-- dxo2photos — AppleScript wrapper for DxO PhotoLab
--
-- The project directory path is stored in Contents/Resources/project_path.txt
-- and written there by build_app.sh. This allows the app to be symlinked
-- (e.g. into /Applications) while all scripts and the Python environment
-- remain in the original project directory.

property copyFlag : "" -- "" = move (default), "--copy" = copy

on projectDir()
    set bundlePath to POSIX path of (path to me)
    set pathFile to bundlePath & "Contents/Resources/project_path.txt"
    return do shell script "cat " & quoted form of pathFile
end projectDir

on outputDir()
    set bundlePath to POSIX path of (path to me)
    set pathFile to bundlePath & "Contents/Resources/output_dir.txt"
    return do shell script "cat " & quoted form of pathFile
end outputDir

on open theFiles
    set projDir to projectDir()
    set pythonBin to projDir & "/.venv/bin/python"
    set pyScript to projDir & "/dxo2photos.py"
    set outDir to outputDir()
    set fileArgs to ""
    repeat with f in theFiles
        set fileArgs to fileArgs & " " & quoted form of POSIX path of f
    end repeat
    set cmd to "export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH; "
    set cmd to cmd & quoted form of pythonBin & " " & quoted form of pyScript
    set cmd to cmd & " --output-dir " & quoted form of outDir
    if copyFlag is not "" then set cmd to cmd & " " & copyFlag
    set cmd to cmd & fileArgs
    try
        do shell script cmd
    on error errMsg
        display dialog "Fehler: " & errMsg buttons {"OK"} default button "OK" with icon stop
    end try
end open

on run
    set pDir to projectDir()
    set msg to "dxo2photos" & return & return & "Project directory:" & return & pDir & return & return & "Configure this app as an External Program in DxO PhotoLab → Preferences → External Programs."
    display dialog msg buttons {"OK"} default button "OK"
end run
