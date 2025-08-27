(
~initSoundPaths = {
	var projectRootPath;

	// 1. Get the directory of the currently open .scd file
	if (thisProcess.nowExecutingPath.notNil) {
		projectRootPath = PathName(thisProcess.nowExecutingPath).pathOnly;
		("Script is located at: " + projectRootPath).postln;
	} {
		// Fallback if run from command line or other method
		projectRootPath = "".resolveRelative;
		("Using current working dir: " + projectRootPath).postln;
	};

	// 2. Build paths relative to the script's location
	~backgroundDir = (projectRootPath +/+ "data/bgSounds/").standardizePath;
	~aiVoicesDir = (projectRootPath +/+ "data/aiVoices/").standardizePath;
	~humanVoicesDir = (projectRootPath +/+ "data/realVoices/").standardizePath;

	"Sound paths initialized:".postln;
	("Background: " + ~backgroundDir).postln;
	("AI Voices: " + ~aiVoicesDir).postln;
	("Human Voices: " + ~humanVoicesDir).postln;
};

// SIMPLER LOADING FUNCTION (CORRECTED)
~loadSounds = {
	var ext;

	"Loading sounds (contains 'wav' approach)...".postln;

	// Reset the lists
	~aiVoicePaths = List.new;
	~humanVoicePaths = List.new;
	~backgroundBuffers = List.new;

	// Load background sounds - just check if extension contains "wav"
	PathName(~backgroundDir).entries.do { |file|
		if (file.isFolder.not) {
			ext = file.extension.toLower;
			if (ext.contains("wav")) { // Just check if it contains "wav"
				("Loading background: " + file.fileName).postln;
				Buffer.read(s, file.fullPath, action: { |buf|
					~backgroundBuffers.add(buf);
					("✓ Loaded: " + file.fileName + " (" + buf.duration.round(0.1) + "s)").postln;
				});
			} {
				("Skipping (wrong format): " + file.fileName + " [ext: '" + ext + "']").postln;
			};
		};
	};

	// Store voice paths
	PathName(~aiVoicesDir).entries.do { |file|
		if (file.isFolder.not) {
			ext = file.extension.toLower;
			if (ext.contains("wav")) {
				~aiVoicePaths.add(file.fullPath);
				("Stored AI: " + file.fileName).postln;
			} {
				("Skipping AI (wrong format): " + file.fileName + " [ext: '" + ext + "']").postln;
			};
		};
	};

	PathName(~humanVoicesDir).entries.do { |file|
		if (file.isFolder.not) {
			ext = file.extension.toLower;
			if (ext.contains("wav")) {
				~humanVoicePaths.add(file.fullPath);
				("Stored Human: " + file.fileName).postln;
			} {
				("Skipping Human (wrong format): " + file.fileName + " [ext: '" + ext + "']").postln;
			};
		};
	};

	"Sound loading started...".postln;
};

// DEBUG VERSION WITH PROPER ERROR HANDLING
~loadSoundsDebug = {
	var ext;

	"Loading sounds (with debug)...".postln;

	// Reset the lists
	~aiVoicePaths = List.new;
	~humanVoicePaths = List.new;
	~backgroundBuffers = List.new;

	// Load background sounds with error handling
	PathName(~backgroundDir).entries.do { |file|
		if (file.isFolder.not) {
			ext = file.extension.toLower;
			if (ext.contains("wav")) {
				("Attempting to load: " + file.fileName).postln;
				try {
					Buffer.read(s, file.fullPath, action: { |buf|
						if (buf.notNil) {
							~backgroundBuffers.add(buf);
							("✓ SUCCESS: Loaded " + file.fileName + " (" + buf.duration.round(0.1) + "s)").postln;
						} {
							("✗ FAILED: Buffer is nil for " + file.fileName).postln;
						};
					});
				} { |error|
					("✗ ERROR loading " + file.fileName + ": " + error.errorString).postln;
				};
			};
		};
	};

	// Store voice paths (unchanged)
	PathName(~aiVoicesDir).entries.do { |file|
		if (file.isFolder.not) {
			ext = file.extension.toLower;
			if (ext.contains("wav")) {
				~aiVoicePaths.add(file.fullPath);
				("Stored AI: " + file.fileName).postln;
			};
		};
	};

	PathName(~humanVoicesDir).entries.do { |file|
		if (file.isFolder.not) {
			ext = file.extension.toLower;
			if (ext.contains("wav")) {
				~humanVoicePaths.add(file.fullPath);
				("Stored Human: " + file.fileName).postln;
			};
		};
	};

	"Sound loading started with debug...".postln;
};

// SEQUENTIAL LOADING WITH COUNTER (NO SYNC)
~loadSoundsSequential = {
	var bgFiles, totalFiles, filesLoaded;

	"Loading sounds sequentially...".postln;

	// Reset the lists
	~aiVoicePaths = List.new;
	~humanVoicePaths = List.new;
	~backgroundBuffers = List.new;

	// Get all WAV files
	bgFiles = PathName(~backgroundDir).entries.select { |file|
		file.isFolder.not and: {file.extension.toLower.contains("wav")}
	};
	totalFiles = bgFiles.size;
	filesLoaded = 0;

	// Store voice paths
	PathName(~aiVoicesDir).entries.do { |file|
		if (file.isFolder.not and: {file.extension.toLower.contains("wav")}) {
			~aiVoicePaths.add(file.fullPath);
			("Stored AI: " + file.fileName).postln;
		};
	};

	PathName(~humanVoicesDir).entries.do { |file|
		if (file.isFolder.not and: {file.extension.toLower.contains("wav")}) {
			~humanVoicePaths.add(file.fullPath);
			("Stored Human: " + file.fileName).postln;
		};
	};

	// Load background sounds sequentially using counter
	bgFiles.do { |file, i|
		("Loading " + (i+1) + "/" + totalFiles + ": " + file.fileName).postln;

		Buffer.read(s, file.fullPath, action: { |buf|
			if (buf.notNil) {
				~backgroundBuffers.add(buf);
				filesLoaded = filesLoaded + 1;
				("✓ Loaded " + filesLoaded + "/" + totalFiles + ": " +
					file.fileName + " (" + buf.duration.round(0.1) + "s)").postln;

				if (filesLoaded == totalFiles) {
					"=== ALL SOUNDS LOADED ===".postln;
					("Background buffers: " + ~backgroundBuffers.size).postln;
				};
			} {
				("✗ Failed to load: " + file.fileName).postln;
			};
		});
	};
};

// FOOLPROOF SEQUENTIAL LOADING
~loadSoundsFoolproof = {
	var bgFiles, totalFiles;

	"Loading sounds (foolproof method)...".postln;

	// Reset the lists
	~aiVoicePaths = List.new;
	~humanVoicePaths = List.new;
	~backgroundBuffers = List.new;

	// Get all WAV files
	bgFiles = PathName(~backgroundDir).entries.select { |file|
		file.isFolder.not and: {file.extension.toLower.contains("wav")}
	};
	totalFiles = bgFiles.size;

	// Store voice paths
	PathName(~aiVoicesDir).entries.do { |file|
		if (file.isFolder.not and: {file.extension.toLower.contains("wav")}) {
			~aiVoicePaths.add(file.fullPath);
			("Stored AI: " + file.fileName).postln;
		};
	};

	PathName(~humanVoicesDir).entries.do { |file|
		if (file.isFolder.not and: {file.extension.toLower.contains("wav")}) {
			~humanVoicePaths.add(file.fullPath);
			("Stored Human: " + file.fileName).postln;
		};
	};

	// Load background sounds in a dedicated Routine
	Routine({
		var cond, buffer;

		bgFiles.do { |file, i|
			cond = Condition.new;

			("Loading " + (i+1) + "/" + totalFiles + ": " + file.fileName).postln;

			Buffer.read(s, file.fullPath, action: { |buf|
				buffer = buf;
				cond.unhang; // Signal that loading is complete
			});

			cond.hang; // Wait for the buffer to load

			if (buffer.notNil) {
				~backgroundBuffers.add(buffer);
				("✓ Loaded: " + file.fileName + " (" + buffer.duration.round(0.1) + "s)").postln;
			} {
				("✗ Failed to load: " + file.fileName).postln;
			};

			0.1.wait; // Short pause
		};

		"=== ALL SOUNDS LOADED ===".postln;
		("Background buffers: " + ~backgroundBuffers.size).postln;
		("AI voice paths: " + ~aiVoicePaths.size).postln;
		("Human voice paths: " + ~humanVoicePaths.size).postln;

		// Now test playback
		if (~backgroundBuffers.size > 0) {
			1.wait;
			"Testing playback of first background sound...".postln;
			{ PlayBuf.ar(2, ~backgroundBuffers[0], doneAction: 2) * 0.5 }.play;
		};
	}).play;
};

~testPlayback = { |type = \background, index = 0|
	case
	{ type == \background } {
		if (~backgroundBuffers.notEmpty) {
			var buf = ~backgroundBuffers.wrapAt(index);
			{ PlayBuf.ar(2, buf, loop: 1) * EnvGen.kr(Env.perc(0.1, 3.0), doneAction: 2) * 0.5 }.play;
			("Playing BACKGROUND: [" ++ index ++ "] for 3 seconds...").postln;
		} {
			"Can't test: No background buffers loaded.".postln;
		};
	}
	{ type == \ai } {
		if (~aiVoicePaths.notEmpty) {
			var path = ~aiVoicePaths.wrapAt(index);
			Buffer.read(s, path, action: { |b|
				{ PlayBuf.ar(1, b, doneAction: 2) * 0.8 }.play;
				("Playing AI VOICE: [" ++ index ++ "] " + b.duration.round(0.01) + "s").postln;
			});
		} {
			"Can't test: No AI voice paths stored.".postln;
		};
	}
	{ type == \human } {
		if (~humanVoicePaths.notEmpty) {
			var path = ~humanVoicePaths.wrapAt(index);
			Buffer.read(s, path, action: { |b|
				{ PlayBuf.ar(1, b, doneAction: 2) * 0.8 }.play;
				("Playing HUMAN VOICE: [" ++ index ++ "] " + b.duration.round(0.01) + "s").postln;
			});
		} {
			"Can't test: No human voice paths stored.".postln;
		};
	};
};

// MANUAL SINGLE FILE LOADING TEST (FIXED)
// MANUAL SINGLE FILE LOADING TEST (WITHOUT SYNC)
~testSingleFile = { |index = 0|
	var bgFiles, file;

	bgFiles = PathName(~backgroundDir).entries.select { |file|
		file.isFolder.not and: {file.extension.toLower.contains("wav")}
	};

	if (bgFiles.size > index) {
		file = bgFiles[index];
		("Testing: " + file.fileName).postln;

		// Load asynchronously with callback
		Buffer.read(s, file.fullPath, action: { |buf|
			if (buf.notNil) {
				("✓ SUCCESS: " + buf.duration + "s, buffer index: " + buf.bufnum).postln;
				buf.free; // Clean up
			} {
				"✗ FAILED: Buffer is nil".postln;
			};
		});
	} {
		"File not found at index ".post; index.postln;
	};
};

// SIMPLE DIAGNOSTIC TEST (NO WAIT)
~diagnoseBuffers = {
	var testBuffer;

	"=== BUFFER DIAGNOSIS ===".postln;

	// Test 1: Check if buffers exist immediately after loading
	("Background buffers count: " + ~backgroundBuffers.size).postln;
	if (~backgroundBuffers.size > 0 and: {~backgroundBuffers[0].notNil}) {
		("First buffer: " + ~backgroundBuffers[0].bufnum).postln;
	} {
		"First buffer is NIL".postln;
	};

	// Test 2: Load and test one buffer directly
	"Testing direct buffer load...".postln;
	testBuffer = Buffer.read(s, "C:/Users/p fh/Desktop/Github/ForestBeings/data/bgSounds/forest-sounds-259933.wav");
	("Direct buffer: " + testBuffer.bufnum).postln;

	// Test 3: Try to play the direct buffer
	{ PlayBuf.ar(2, testBuffer, doneAction: 2) * 0.5 }.play;
	"Playing direct buffer...".postln;
};

// SIMPLE DIRECT LOADING (NO CALLBACKS) - FIXED
~loadSoundsDirect = {
	var bgFiles;

	"Loading sounds directly...".postln;

	// Reset the lists
	~aiVoicePaths = List.new;
	~humanVoicePaths = List.new;
	~backgroundBuffers = List.new;

	// Get all WAV files
	bgFiles = PathName(~backgroundDir).entries.select { |file|
		file.isFolder.not and: {file.extension.toLower.contains("wav")}
	};

	// Store voice paths
	PathName(~aiVoicesDir).entries.do { |file|
		if (file.isFolder.not and: {file.extension.toLower.contains("wav")}) {
			~aiVoicePaths.add(file.fullPath);
			("Stored AI: " + file.fileName).postln;
		};
	};

	PathName(~humanVoicesDir).entries.do { |file|
		if (file.isFolder.not and: {file.extension.toLower.contains("wav")}) {
			~humanVoicePaths.add(file.fullPath);
			("Stored Human: " + file.fileName).postln;
		};
	};

	// Load background sounds DIRECTLY (synchronous)
	bgFiles.do { |file, i|
		var buffer;
		("Loading " + (i+1) + "/" + bgFiles.size + ": " + file.fileName).postln;
		try {
			buffer = Buffer.read(s, file.fullPath);
			~backgroundBuffers.add(buffer);
			("✓ Direct load: " + file.fileName + " -> buffer " + buffer.bufnum).postln;
		} { |error|
			("✗ Failed: " + file.fileName + " - " + error.errorString).postln;
		};
	};

	"=== LOADING COMPLETE ===".postln;
	("Background buffers: " + ~backgroundBuffers.size).postln;
	("AI voice paths: " + ~aiVoicePaths.size).postln;
	("Human voice paths: " + ~humanVoicePaths.size).postln;
};
)

(
// TEST THE FILTERING LOGIC (CORRECTED)
~testFiltering = {
	var testDir, entries, filtered;

	"=== TESTING FILE FILTERING ===".postln;

	testDir = ~backgroundDir;
	entries = PathName(testDir).entries;

	("Raw entries found: " + entries.size).postln;
	entries.do { |item, i|
		("  " + i + ": " + item.fileName +
			" [Folder: " + item.isFolder +
			", Ext: '" + item.extension + "']").postln;
	};

	"".postln;
	("Testing filter: isFolder.not and: {['wav', 'aiff', 'mp3'].includes(item.extension.toLower)}").postln;

	filtered = entries.select { |file|
		file.isFolder.not and: {["wav", "aiff", "mp3"].includes(file.extension.toLower)}
	};

	("Filtered results: " + filtered.size).postln;
	filtered.do { |item, i|
		("  " + i + ": " + item.fileName).postln;
	};
};
)

// TEST IN ORDER:
~initSoundPaths.();  // 1. Set the paths
~testFiltering.();
~debugDirectories.();
~loadSounds.();   // 2. Load sounds (wait for "All sounds processed.")
~loadSoundsDebug.();
~loadSoundsSequential.();
~loadSoundsFoolproof.();
~loadSoundsDirect.();
~diagnoseBuffers.();
~checkStatus = {
	("Background buffers: " + ~backgroundBuffers.size).postln;
	("AI voice paths: " + ~aiVoicePaths.size).postln;
	("Human voice paths: " + ~humanVoicePaths.size).postln;
};
// First test individual files
~testSingleFile.(0); // Test first file
~testSingleFile.(1); // Test second file
~testSingleFile.(2); // Test third file

// Then run the sequential loader
~loadSoundsSequential.();
~loadSoundsDirect.();
(
Routine({
	5.do { |i|
		("Check #" + (i+1)).postln;
		~checkStatus.();
		2.wait;
	};
	"Finished checking".postln;
}).play;
)
~testPlayback.(\background, 0); // 3. Test a background sound
~testPlayback.(\ai, 0);         // 4. Test an AI voice
~testPlayback.(\human, 0);      // 5. Test a human voice

// CONFIRM FILES CAN LOAD
(
var testPath = "C:/Users/p fh/Desktop/Github/ForestBeings/data/bgSounds/forest-sounds-259933.wav";
Buffer.read(s, testPath, action: { |buf|
    ("SUCCESS! Single file: " + buf.duration + "s").postln;
});
)

(
Routine({
	3.wait;
	"=== STATUS AFTER 3 SECONDS ===".postln;
	("Background buffers: " + ~backgroundBuffers.size).postln;
	("AI voice paths: " + ~aiVoicePaths.size).postln;
	("Human voice paths: " + ~humanVoicePaths.size).postln;
}).play;
)

// MANUAL TEST WITH ERROR HANDLING
(
var testPath = "C:/Users/p fh/Desktop/Github/ForestBeings/data/bgSounds/forest-sounds-259933.wav";
"Testing single file with error handling...".postln;

try {
	Buffer.read(s, testPath, action: { |buf|
		if (buf.notNil) {
			("✓ SINGLE FILE SUCCESS: " + buf.duration + "s").postln;
		} {
			"✗ SINGLE FILE FAILED: Buffer is nil".postln;
		};
	});
} { |error|
	("✗ SINGLE FILE ERROR: " + error.errorString).postln;
};
)

// First test a single file
(
var testPath = "C:/Users/p fh/Desktop/Github/ForestBeings/data/bgSounds/forest-sounds-259933.wav";
Buffer.read(s, testPath, action: { |buf|
	if (buf.notNil) {
		("✓ SINGLE FILE: " + buf.duration + "s").postln;
	} {
		"✗ SINGLE FILE: Buffer is nil".postln;
	};
});
)

// Then run the debug loader
~loadSoundsDebug.();

// Check repeatedly
(
Routine({
	5.do { |i|
		("Check #" + (i+1) + ": Background buffers = " + ~backgroundBuffers.size).postln;
		1.wait;
	};
}).play;
)

(
Routine({
	5.do { |i|
		("Status check #" + (i+1) + ": " + ~backgroundBuffers.size + " buffers loaded").postln;
		2.wait;
	};
}).play;
)

(
// MANUAL APPROACH - Just test that we can create and use buffers
~testManualBuffer = {
	"Testing manual buffer creation...".postln;

	// Manually load one buffer and add it to the list
	Buffer.read(s, "C:/Users/p fh/Desktop/Github/ForestBeings/data/bgSounds/forest-sounds-259933.wav", action: { |buf|
		~backgroundBuffers = [buf]; // Manually set the list
		("Manual buffer loaded: " + buf.duration + "s, index: " + buf.bufnum).postln;

		// Test playback
		{ PlayBuf.ar(2, buf, doneAction: 2) * 0.5 }.play;
		"Playing manual buffer...".postln;
	});
};
)
~testManualBuffer.();

// TEST 1: Play a background sound from the list
("Testing background buffer 0: " + ~backgroundBuffers[0].bufnum).postln;
{ PlayBuf.ar(2, ~backgroundBuffers[0], doneAction: 2) * 0.5 }.play;

// TEST 2: Test playing a voice from the path list
(
if (~aiVoicePaths.size > 0) {
	"Testing AI voice playback...".postln;
	Buffer.read(s, ~aiVoicePaths[0], action: { |buf|
		{ PlayBuf.ar(1, buf, doneAction: 2) * 0.8 }.play;
	});
};
)

// TEST 3: Verify all buffers are accessible
"=== BUFFER VERIFICATION ===".postln;
~backgroundBuffers.do { |buf, i|
	("Buffer " + i + ": #" + buf.bufnum + ", " + buf.duration.round(0.1) + "s").postln;
};