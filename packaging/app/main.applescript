-- Stem Lab droplet: drop audio files on the icon (or double-click to pick one).
-- Each file gets a Terminal window running the split pipeline so the
-- progress bars are visible.

on open theFiles
	repeat with f in theFiles
		splitInTerminal(POSIX path of f)
	end repeat
end open

on run
	set f to choose file with prompt "Choose an audio file to split into stems:" of type {"public.audio"}
	splitInTerminal(POSIX path of f)
end run

on splitInTerminal(audioPath)
	set runner to (POSIX path of (path to me)) & "Contents/Resources/stemlab-run.sh"
	set cmd to "clear; " & quoted form of runner & " " & quoted form of audioPath
	tell application "Terminal"
		activate
		do script cmd
	end tell
end splitInTerminal
