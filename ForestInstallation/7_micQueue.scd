// =============================================
// COMPLETE INTEGRATED SYSTEM
// Background Music + Voice Queue + Voice Recording
// =============================================

(
// ========== SOUND PATH INITIALIZATION ==========
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
	~backgroundDir = (projectRootPath +/+ "dataTest/bgSounds/").standardizePath;
	~aiVoicesDir = (projectRootPath +/+ "dataTest/aiVoices/").standardizePath;
	~humanVoicesDir = (projectRootPath +/+ "dataTest/realVoices/").standardizePath;

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

	// Load background sounds - SIMPLIFIED without complex checks
	bgFiles.do { |file, i|
		("Loading " + (i+1) + "/" + bgFiles.size + ": " + file.fileName).postln;
		try {
			var buffer = Buffer.read(s, file.fullPath);
			~backgroundBuffers.add(buffer);
			("✓ Loaded: " + file.fileName + " -> buffer " + buffer.bufnum).postln;
		} { |error|
			("✗ Failed: " + file.fileName + " - " + error.errorString).postln;
		};
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

	"=== LOADING COMPLETE ===".postln;
	("Background buffers: " + ~backgroundBuffers.size).postln;
	("AI voice paths: " + ~aiVoicePaths.size).postln;
	("Human voice paths: " + ~humanVoicePaths.size).postln;
};

// ========== QUEUE SYSTEM ==========
~initQueue = {
	// Initialize the queue system
	~voiceQueue = List.new;
	~isPlaying = false;
	~currentPlayer = nil;
	~queueActive = false;
	~bgPlayer = nil;
	~currentBgIndex = 0;

	"Queue system initialized".postln;
};

~startQueue = { |bgIndex = 0, bgVolume = 0.5|
	"Starting queue with background cycling...".postln;
	~queueActive = true;
	~currentBgIndex = bgIndex;

	// Start background sound with cycling
	~startBackgroundCycling.(bgVolume);

	// Only populate if queue is empty
	if (~voiceQueue.size == 0) {
		~populateRandomQueue;
	};

	// Start processing queue after a short delay
	SystemClock.sched(1.0, {
		if (~queueActive && ~voiceQueue.size > 0 && ~isPlaying.not) {
			"Starting voice processing...".postln;
			~processQueue.();
		} {
			if (~voiceQueue.size == 0) {
				"Queue empty - populating...".postln;
				~populateRandomQueue;
				SystemClock.sched(1.0, { ~processQueue.(); nil });
			};
		};
		nil;
	});
};

~validateBuffers = {
	"=== VALIDATING BUFFERS ===".postln;

	// Create a new list for valid buffers
	~validBackgroundBuffers = List.new;

	~backgroundBuffers.do { |buf, i|
		if (buf.notNil && {buf.numChannels.notNil} && {buf.numFrames > 0}) {
			~validBackgroundBuffers.add(buf);
			("✅ Buffer " + i + ": " + PathName(buf.path).fileName + " - " +
				buf.numChannels + " channels, " + buf.duration.round(0.1) + "s").postln;
		} {
			("❌ Invalid buffer " + i + ": " + (if (buf.notNil) { PathName(buf.path).fileName } { "nil" })).postln;
		};
	};

	// Replace with only valid buffers
	~backgroundBuffers = ~validBackgroundBuffers;
	("Valid background buffers: " + ~backgroundBuffers.size).postln;
};

~startBackgroundCycling = { |bgVolume = 0.5|
	if (~bgPlayer.notNil) { ~bgPlayer.free; ~bgPlayer = nil; };

	if (~backgroundBuffers.notNil && {~backgroundBuffers.size > 0}) {
		var buf = ~backgroundBuffers[~currentBgIndex];

		// Simple try-catch for playing
		try {
			~bgPlayer = {
				var sig = PlayBuf.ar(2, buf, rate: BufRateScale.kr(buf), loop: 0, doneAction: 2);
				sig * bgVolume;
			}.play;

			("✅ Background started: [" + ~currentBgIndex + "] - " +
				PathName(buf.path).fileName).postln;

			// Schedule next background sound
			SystemClock.sched(buf.duration, {
				if (~queueActive) {
					~currentBgIndex = (~currentBgIndex + 1) % ~backgroundBuffers.size;
					~startBackgroundCycling.(bgVolume);
				};
				nil;
			});
		} { |error|
			("❌ Background failed: [" + ~currentBgIndex + "] - " + error.errorString).postln;
			// Skip to next buffer
			~currentBgIndex = (~currentBgIndex + 1) % ~backgroundBuffers.size;
			SystemClock.sched(0.5, { ~startBackgroundCycling.(bgVolume); nil });
		};
	} {
		"⚠️ Warning: No background buffers available".postln;
	};
};

// Also, let's fix the recording issue - make sure the humanVoicesDir is accessible
~stopRecording = { |timestamp|
	var filename, path, actualDuration;
	if (~isRecording.not) {
		"Not currently recording".postln;
		^nil;
	};

	~isRecording = false;
	if (~recordingCheckRoutine.notNil) { ~recordingCheckRoutine.stop; ~recordingCheckRoutine = nil; };
	if (~oscResponder.notNil) { ~oscResponder.free; ~oscResponder = nil; };
	if (~recorder.notNil) { ~recorder.free; ~recorder = nil; };

	if (timestamp.isNil) { timestamp = Date.getDate.stamp; };

	// Create filename and path
	filename = "voice_" ++ timestamp ++ ".wav";
	path = ~humanVoicesDir +/+ filename;
	actualDuration = ~recordingBuffer.duration - ~silenceTimer;

	// Save recording
	try {
		~recordingBuffer.write(path, "WAV", "int16", 0, 0, true);
		("💾 Recording saved: " + filename + " (" + actualDuration.round(0.1) + "s)").postln;

		// Add to human voices list
		if (~humanVoicePaths.isNil) { ~humanVoicePaths = List.new; };
		~humanVoicePaths.add(path);

		// Add to current queue
		~voiceQueue.add([\human, ~humanVoicePaths.size - 1, path]);
		("✅ Auto-added to queue. Queue now has " + ~voiceQueue.size + " items").postln;
	} { |error|
		("❌ Failed to save recording: " + error.errorString).postln;
	};

	~recordingBuffer.free;
	~recordingBuffer = nil;

	^path;
};

~populateRandomQueue = {
	var currentSize = ~voiceQueue.size;

	// Add AI voices if we have them
	if (~aiVoicePaths.notNil && {~aiVoicePaths.size > 0}) {
		~aiVoicePaths.do { |path, i|
			~voiceQueue.add([\ai, i, path]);
		};
	};

	// Add human voices if we have them
	if (~humanVoicePaths.notNil && {~humanVoicePaths.size > 0}) {
		~humanVoicePaths.do { |path, i|
			~voiceQueue.add([\human, i, path]);
		};
	};

	// Only shuffle if we added new items
	if (~voiceQueue.size > currentSize) {
		var newItems = ~voiceQueue.copyRange(currentSize, ~voiceQueue.size - 1);
		newItems = newItems.scramble;
		~voiceQueue = ~voiceQueue.copyRange(0, currentSize - 1) ++ newItems;
	};

	("Queue now has " + ~voiceQueue.size + " voices").postln;
};

~processQueue = {
	if (~queueActive and: { ~isPlaying.not } and: { ~voiceQueue.size > 0 }) {
		var nextItem = ~voiceQueue.removeAt(0);
		var type = nextItem[0];
		var index = nextItem[1];
		var path = nextItem[2];
		var silenceGap = 4.0;

		("🎵 NOW PLAYING: " + type + " [" + index + "] - " + PathName(path).fileName).postln;
		~isPlaying = true;

		Buffer.read(s, path, action: { |buf|
			var duration = buf.duration;
			var numChannels = buf.numChannels;

			~currentPlayer = {
				var sig = PlayBuf.ar(numChannels, buf, rate: BufRateScale.kr(buf), doneAction: 2);
				if (numChannels == 1) { sig = Pan2.ar(sig) };
				sig * 1.0
			}.play;

			// Schedule next voice with silence gap
			SystemClock.sched(duration + silenceGap, {
				~isPlaying = false;
				~currentPlayer = nil;
				buf.free;

				if (~queueActive) {
					if (~voiceQueue.size == 0) {
						"Queue empty - adding more voices...".postln;
						~populateRandomQueue.();
					};

					if (~voiceQueue.size > 0) {
						SystemClock.sched(0.5, { ~processQueue.(); nil });
					} {
						SystemClock.sched(2.0, { ~processQueue.(); nil });
					};
				};
				nil;
			});
		});
	};
};

~stopQueue = {
	"Stopping queue...".postln;
	~queueActive = false;
	~isPlaying = false;

	if (~currentPlayer.notNil) {
		~currentPlayer.free;
		~currentPlayer = nil;
	};

	if (~bgPlayer.notNil) {
		~bgPlayer.free;
		~bgPlayer = nil;
	};
};

~queueStatus = {
	"=== QUEUE STATUS ===".postln;
	("Queue active: " + ~queueActive).postln;
	("Currently playing: " + ~isPlaying).postln;
	("Background playing: " + (~bgPlayer.notNil)).postln;
	("Current background index: " + ~currentBgIndex).postln;
	("Voice queue items: " + ~voiceQueue.size).postln;
};

// ========== VOICE RECORDING SYSTEM ==========
~initRecording = {
	~recorder = nil;
	~isRecording = false;
	~recordingBuffer = nil;
	~silenceThreshold = 0.05;
	~maxSilenceTime = 2.0;
	~silenceTimer = 0;
	~recordingCheckRoutine = nil;

	"Voice-activated recording system initialized".postln;
};

~startVoiceActivatedRecording = {
	var timestamp, bufferDuration = 60.0;

	if (~isRecording) {
		"Already recording!".postln;
		^nil;
	};

	~isRecording = true;
	~silenceTimer = 0;
	timestamp = Date.getDate.stamp;

	~recordingBuffer = Buffer.alloc(s, s.sampleRate * bufferDuration, 2);

	~recorder = {
		var input = SoundIn.ar([0, 1]);
		var inputLevel = Amplitude.kr(input).max;
		var isSilent = inputLevel < ~silenceThreshold;

		SendReply.kr(Impulse.kr(10), '/recording_level', [inputLevel, isSilent]);
		RecordBuf.ar(input, ~recordingBuffer, loop: 0);
	}.play;

	~recordingCheckRoutine = Routine({
		"🎤 Voice-activated recording started. Speak now...".postln;
		while { ~isRecording } { 0.1.wait; };
	}).play;

	~oscResponder = OSCFunc({ |msg|
		var inputLevel = msg[3], isSilent = msg[4];
		if (isSilent > 0) {
			~silenceTimer = ~silenceTimer + 0.1;
			if (~silenceTimer >= ~maxSilenceTime) {
				"Silence detected - stopping recording".postln;
				~stopRecording.(timestamp);
			};
		} {
			if (~silenceTimer > 0) {
				~silenceTimer = 0;
				"Sound detected - recording continues".postln;
			};
		};
	}, '/recording_level');

	^timestamp;
};

// FINAL FIXED stopRecording function - no var declarations
~stopRecording = { |timestamp|
	if (~isRecording.not) {
		"Not currently recording".postln;
		^nil;
	};

	~isRecording = false;
	if (~recordingCheckRoutine.notNil) { ~recordingCheckRoutine.stop; ~recordingCheckRoutine = nil; };
	if (~oscResponder.notNil) { ~oscResponder.free; ~oscResponder = nil; };
	if (~recorder.notNil) { ~recorder.free; ~recorder = nil; };

	if (timestamp.isNil) { timestamp = Date.getDate.stamp; };

	// Save recording directly
	~recordingBuffer.write(
		~humanVoicesDir +/+ "voice_" ++ timestamp ++ ".wav",
		"WAV", "int16", 0, 0, true
	);

	("💾 Recording saved: voice_" ++ timestamp ++ ".wav" + " (" + (~recordingBuffer.duration - ~silenceTimer).round(0.1) + "s)").postln;

	// Use the path directly without storing in a variable
	if (~humanVoicePaths.isNil) { ~humanVoicePaths = List.new; };
	~humanVoicePaths.add(~humanVoicesDir +/+ "voice_" ++ timestamp ++ ".wav");
	~voiceQueue.add([\human, ~humanVoicePaths.size - 1, ~humanVoicesDir +/+ "voice_" ++ timestamp ++ ".wav"]);
	("✅ Auto-added to queue. Queue now has " + ~voiceQueue.size + " items").postln;

	~recordingBuffer.free;
	~recordingBuffer = nil;

	^~humanVoicesDir +/+ "voice_" ++ timestamp ++ ".wav";
};

~setRecordingThreshold = { |threshold = 0.05, maxSilence = 2.0|
	~silenceThreshold = threshold.max(0.001);
	~maxSilenceTime = maxSilence.max(0.5);
	("Threshold: " + ~silenceThreshold + ", Max silence: " + ~maxSilenceTime + "s").postln;
};

~toggleRecording = {
	if (~isRecording) {
		~stopRecording.();
	} {
		~startVoiceActivatedRecording.();
	};
};

~monitorMicrophone = { |volume = 0.1|
	~micMonitor = {
		var input = SoundIn.ar([0, 1]);
		var level = Amplitude.kr(input).max;
		SendReply.kr(Impulse.kr(4), '/mic_level', [level, level > ~silenceThreshold]);
		input * volume;
	}.play;

	~micLevelResponder = OSCFunc({ |msg|
		var level = msg[3], isAboveThreshold = msg[4];
		var bars = "|" ++ ("=" ! (level * 20).round) ++ "|";
		if (isAboveThreshold > 0) {
			("MIC: " + bars + " ✓").postln;
		} {
			("MIC: " + bars + " ✗").postln;
		};
	}, '/mic_level');

	"Microphone monitoring started".postln;
};

~stopMonitoring = {
	if (~micMonitor.notNil) { ~micMonitor.free; ~micMonitor = nil; };
	if (~micLevelResponder.notNil) { ~micLevelResponder.free; ~micLevelResponder = nil; };
	"Microphone monitoring stopped".postln;
};

~recordingStatus = {
	"=== RECORDING STATUS ===".postln;
	("Currently recording: " + ~isRecording).postln;
	("Silence timer: " + ~silenceTimer.round(0.1) + "s").postln;
};

// ========== COMPLETE ENVIRONMENT CONTROL ==========
~startCompleteEnvironment = { |bgVolume = 0.15|
	"🚀 Starting complete environment...".postln;
	~initSoundPaths.();
	~loadSoundsDirect.();

	// Validate buffers before starting
	~validateBuffers.();

	~initQueue.();
	~initRecording.();
	~populateRandomQueue.();
	~startQueue.(0, bgVolume);
	"✅ Environment ready! Background music playing + voice queue active".postln;
	"🎤 Voice recording system ready - users can approach microphone".postln;
};


// Test microphone and recording separately
~testRecordingSystem = {
	"=== TESTING RECORDING SYSTEM ===".postln;

	// Test microphone
	{ SoundIn.ar([0, 1]) * 0.5 }.play;
	"Microphone test - you should hear yourself".postln;

	// Test recording after a delay
	SystemClock.sched(3.0, {
		"Testing recording system...".postln;
		~initRecording.();
		~startVoiceActivatedRecording.();

		// Stop recording after 5 seconds
		SystemClock.sched(8.0, {
			~stopRecording.();
			"Recording test complete".postln;
			nil;
		});
		nil;
	});
};

// Test background sounds separately
~testBackgroundSounds = {
	"=== TESTING BACKGROUND SOUNDS ===".postln;
	if (~backgroundBuffers.size > 0) {
		("Testing background sound 0 of " + ~backgroundBuffers.size).postln;
		{ PlayBuf.ar(2, ~backgroundBuffers[0], doneAction: 2) * 0.5 }.play;
	} {
		"No background buffers to test".postln;
	};
};
)

// =============================================
// USAGE EXAMPLES
// =============================================

// First, test if background sounds load properly
~initSoundPaths.();
~loadSoundsDirect.();

// Test if background sounds work
~testBackgroundSounds.();

// Test if recording works
~testRecordingSystem.();

// If both work, then start the complete environment
~startCompleteEnvironment.(0.15);

// 1. Start everything with one command:
~startCompleteEnvironment.(0.15); // Volume 0.15

// 2. Check status:
~environmentStatus.();

// 3. Users can now approach microphone and speak
//    Recordings will be automatically added to the queue!

// 4. Stop everything:
~stopCompleteEnvironment.();

// Manual controls if needed:
~toggleRecording.(); // Start/stop recording manually
~setRecordingThreshold.(0.03, 1.5); // Adjust sensitivity
~monitorMicrophone.(0.1); // Monitor mic levels