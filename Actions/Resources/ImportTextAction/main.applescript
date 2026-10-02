-- main.applescript
-- ProVoc

--  Created by Simon Bovet on 19.05.06.
--  Copyright 2006 Arizona Software. All rights reserved.

-- (The commands of ProVoc are written with their event codes, and the application is
-- named by its identifier when the action runs: the script then compiles without
-- ProVoc being known to the system that builds it. The original line is quoted.)

on run {input, parameters}
	
	set theNewDocument to |newDocument| of parameters
	set theApplication to "ch.arizona-software.provoc"
	tell application id theApplication
		-- import text input new document theNewDocument
		«event PVAEImTx» input given «class newD»:theNewDocument
	end tell
	
	return input
	
end run
