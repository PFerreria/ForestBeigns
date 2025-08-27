(
~initSoundPaths = {
	var projectRootPath;

	// Get the directory of the currently open .scd file
	if (thisProcess.nowExecutingPath.notNil) {
		projectRootPath = PathName(thisProcess.nowExecutingPath).pathOnly;
	} {
		// Fallback if run from command line or other method
		projectRootPath = "".resolveRelative;
	};

	// Build paths relative to the script's location
	~backgroundDir = (projectRootPath +/+ "data/bgSounds/").standardizePath;
	~aiVoicesDir = (projectRootPath +/+ "data/aiVoices/").standardizePath;
	~humanVoicesDir = (projectRootPath +/+ "data/realVoices/").standardizePath;

	"Sound paths initialized:".postln;
	("Background: " + ~backgroundDir).postln;
	("AI Voices: " + ~aiVoicesDir).postln;
	("Human Voices: " + ~humanVoicesDir).postln;
};

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
		};
	};

	PathName(~humanVoicesDir).entries.do { |file|
		if (file.isFolder.not and: {file.extension.toLower.contains("wav")}) {
			~humanVoicePaths.add(file.fullPath);
		};
	};

	// Load background sounds DIRECTLY (synchronous)
	bgFiles.do { |file, i|
		var buffer;
		("Loading " + (i+1) + "/" + bgFiles.size + ": " + file.fileName).postln;
		try {
			buffer = Buffer.read(s, file.fullPath);
			~backgroundBuffers.add(buffer);
			("✓ Loaded: " + file.fileName + " -> buffer " + buffer.bufnum).postln;
		} { |error|
			("✗ Failed: " + file.fileName + " - " + error.errorString).postln;
		};
	};

	"=== LOADING COMPLETE ===".postln;
	("Background buffers: " + ~backgroundBuffers.size).postln;
	("AI voice paths: " + ~aiVoicePaths.size).postln;
	("Human voice paths: " + ~humanVoicePaths.size).postln;
};

// IMPROVED PLAYBACK FUNCTIONS WITH BETTER AUDIO QUALITY
~playBackground = { |index = 0, vol = 0.7|
	if (~backgroundBuffers.notEmpty) {
		var buf = ~backgroundBuffers.wrapAt(index);
		{
			var sig = PlayBuf.ar(2, buf, loop: 1) * vol;
			sig * EnvGen.kr(Env.perc(0.1, 3.0), doneAction: 2);
		}.play;
		("Playing BACKGROUND: [" ++ index ++ "] at volume " + vol).postln;
	} {
		"No background buffers loaded.".postln;
	};
};

// CHECK AUDIO FILE PROPERTIES
~checkAudioProperties = {
	"=== AUDIO FILE PROPERTIES ===".postln;

	// Check background sounds
	"Background sounds:".postln;
	~backgroundBuffers.do { |buf, i|
		("  " + i + ": " + buf.numChannels + " channels, " +
			buf.sampleRate + " Hz, " + buf.duration.round(0.1) + "s").postln;
	};

	// Check AI voices
	"AI voices:".postln;
	~aiVoicePaths.do { |path, i|
		Buffer.read(s, path, action: { |b|
			("  " + i + ": " + b.numChannels + " channels, " +
				b.sampleRate + " Hz, " + b.duration.round(0.1) + "s").postln;
			b.free;
		});
	};

	// Check human voices
	"Human voices:".postln;
	~humanVoicePaths.do { |path, i|
		Buffer.read(s, path, action: { |b|
			("  " + i + ": " + b.numChannels + " channels, " +
				b.sampleRate + " Hz, " + b.duration.round(0.1) + "s").postln;
			b.free;
		});
	};
};

~playVoice = { |type = \ai, index = 0, vol = 1.0|
	var pathList, path;

	pathList = case
		{ type == \ai } { ~aiVoicePaths }
		{ type == \human } { ~humanVoicePaths };

	if (pathList.notEmpty) {
		path = pathList.wrapAt(index);
		Buffer.read(s, path, action: { |b|
			{
				var sig = PlayBuf.ar(1, b, doneAction: 2) * vol;
				Pan2.ar(sig); // Convert mono to stereo
			}.play;
			("Playing " ++ type.asString.toUpper ++ " VOICE: [" ++ index ++ "] " +
				b.duration.round(0.01) + "s at volume " + vol).postln;
		});
	} {
		("No " ++ type ++ " voice paths stored.").postln;
	};
};

// CORRECTED PLAYBACK FUNCTIONS
~testPlayback = { |type = \background, index = 0|
	case
	{ type == \background } {
		if (~backgroundBuffers.notEmpty) {
			var buf = ~backgroundBuffers.wrapAt(index);
			{ PlayBuf.ar(2, buf, rate: BufRateScale.kr(buf), loop: 1) * 0.8 }.play; // Stereo, rate-corrected, louder
			("Playing BACKGROUND: [" ++ index ++ "] - " + buf.duration.round(0.1) + "s").postln;
		} {
			"Can't test: No background buffers loaded.".postln;
		};
	}
	{ type == \ai } {
		if (~aiVoicePaths.notEmpty) {
			var path = ~aiVoicePaths.wrapAt(index);
			Buffer.read(s, path, action: { |b|
				{ PlayBuf.ar(2, b, rate: BufRateScale.kr(b), doneAction: 2) * 1.0 }.play; // Stereo, rate-corrected
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
				{ PlayBuf.ar(2, b, rate: BufRateScale.kr(b), doneAction: 2) * 1.0 }.play; // Stereo, rate-corrected
				("Playing HUMAN VOICE: [" ++ index ++ "] " + b.duration.round(0.01) + "s").postln;
			});
		} {
			"Can't test: No human voice paths stored.".postln;
		};
	};
};

// FUNCTION TO CHECK STATUS
~checkStatus = {
	("Background buffers: " + ~backgroundBuffers.size).postln;
	("AI voice paths: " + ~aiVoicePaths.size).postln;
	("Human voice paths: " + ~humanVoicePaths.size).postln;
};
)

// ==================== USAGE EXAMPLES ====================

// 1. Initialize paths
~initSoundPaths.();

// 2. Load sounds
~loadSoundsDirect.();

~testPlayback.();

// Test background sounds
~testPlayback.(\background, 0); // First background
~testPlayback.(\background, 1); // Second background
~testPlayback.(\background, 2); // Third background

// Test voices
~testPlayback.(\ai, 0);      // AI voice
~testPlayback.(\human, 0);   // Human voice

// 4. Check status
~checkStatus.();

~checkAudioProperties.();