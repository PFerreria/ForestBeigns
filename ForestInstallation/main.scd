// ======================================================================================
//  Main File For Forest Beings Aster+ Project
// ======================================================================================

// Description


// SETUP

(
~setupServer = {
	Server.killAll;
	s.quit;
	"All servers killed.".postln;

	s.options.numInputBusChannels = 2;  // Stereo input
	s.options.numOutputBusChannels = 2; // Stereo output
	// s.options.inDevice = "Your-Audio-Interface-Name";
	// s.options.outDevice = "Your-Audio-Interface-Name";
	s.options.sampleRate = 8000;
	s.options.blockSize = 256;
	s.options.memSize = 2.pow(20);

	"Server configured. Run Snippet 2: ~bootServer.()".postln;
};

~bootServer = {
	s.waitForBoot {
		"Server booted successfully!".postln;
		"Run ~testAudioIO.() to verify input/output.".postln;
	};
};

~testAudioIO = {
	// Test input
	{ SoundIn.ar(0!2) * 0.5 }.play;
	"Testing microphone input... (you should hear yourself)".postln;

	// Test output with synth
	{ SinOsc.ar(440, 0, 0.2) * EnvGen.kr(Env.perc(0.01, 0.5), doneAction:2) }.play;
	"Testing speaker output... (you should hear a beep)".postln;
};
)





// SOUNDLOAD

(
~initSoundPaths = {
	var projectRootPath;

	if (thisProcess.nowExecutingPath.notNil) {
		projectRootPath = PathName(thisProcess.nowExecutingPath).pathOnly;
	} {
		projectRootPath = "".resolveRelative;
	};
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
	~aiVoicePaths = List.new;
	~humanVoicePaths = List.new;
	~backgroundBuffers = List.new;

	bgFiles = PathName(~backgroundDir).entries.select { |file|
		file.isFolder.not and: {file.extension.toLower.contains("wav")}
	};

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

(
~runAll = {
	~setupServer.();    // Configure
	~bootServer.();     // Boot
	~testAudioIO.();    // Verify
	~initSoundPaths.();
	~loadSoundsDirect.();
}
)
// ==================== USAGE EXAMPLES ====================

~runAll.();


~setupServer.();    // Configure
~bootServer.();     // Boot
~testAudioIO.();    // Verify
~initSoundPaths.();
~loadSoundsDirect.();
~testPlayback.();
~testPlayback.(\ai, 0);      // AI voice
~testPlayback.(\human, 0);   // Human voice
~checkStatus.();
~checkAudioProperties.();
