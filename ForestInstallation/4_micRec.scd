// =============================================
// VOICE-ACTIVATED RECORDING SYSTEM (NO DIRECTORY CREATION)
// =============================================

(
~initRecording = {
	// Initialize recording system - NO DIRECTORY CREATION
	~recorder = nil;
	~isRecording = false;
	~recordingBuffer = nil;
	~silenceThreshold = 0.05;
	~maxSilenceTime = 2.0;
	~silenceTimer = 0;
	~recordingCheckRoutine = nil;

	"Voice-activated recording system initialized".postln;
	("Silence threshold: " + ~silenceThreshold + ", Max silence time: " + ~maxSilenceTime + "s").postln;
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
		"Voice-activated recording started. Speak now...".postln;

		while { ~isRecording } {
			0.1.wait;
		};
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

~stopRecording = { |timestamp|
	var filename, path, actualDuration;

	if (~isRecording.not) {
		"Not currently recording".postln;
		^nil;
	};

	~isRecording = false;

	if (~recordingCheckRoutine.notNil) {
		~recordingCheckRoutine.stop;
		~recordingCheckRoutine = nil;
	};

	if (~oscResponder.notNil) {
		~oscResponder.free;
		~oscResponder = nil;
	};

	if (~recorder.notNil) {
		~recorder.free;
		~recorder = nil;
	};

	if (timestamp.isNil) {
		timestamp = Date.getDate.stamp;
	};

	filename = "voice_" ++ timestamp ++ ".wav";

	// Use the existing realVoices directory - NO CREATION, JUST USE IT
	path = ~humanVoicesDir +/+ filename;

	actualDuration = ~recordingBuffer.duration - ~silenceTimer;

	// Save directly to realVoices folder
	~recordingBuffer.write(path, "WAV", "int16", 0, 0, true);

	("Recording saved to realVoices: " + filename + " (" + actualDuration.round(0.1) + "s)").postln;

	if (~humanVoicePaths.isNil) { ~humanVoicePaths = List.new; };
	~humanVoicePaths.add(path);
	("Added to human voice paths").postln;

	~recordingBuffer.free;
	~recordingBuffer = nil;

	SystemClock.sched(0.5, {
		if (~humanVoicePaths.notEmpty) {
			var latestIndex = ~humanVoicePaths.size - 1;
			~addToQueue.(\human, latestIndex);
			("✅ Auto-added recording to queue").postln;
		};
		nil;
	});

	^path;
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

// Remove any directory-related functions completely
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
	if (~micMonitor.notNil) {
		~micMonitor.free;
		~micMonitor = nil;
	};
	if (~micLevelResponder.notNil) {
		~micLevelResponder.free;
		~micLevelResponder = nil;
	};
	"Microphone monitoring stopped".postln;
};

~recordingStatus = {
	"=== RECORDING STATUS ===".postln;
	("Currently recording: " + ~isRecording).postln;
	("Silence timer: " + ~silenceTimer.round(0.1) + "s").postln;
	("Threshold: " + ~silenceThreshold + ", Max silence: " + ~maxSilenceTime + "s").postln;
};
)

// =============================================
// TEST THE SYSTEM
// =============================================

(
~testVoiceActivated = {
	"Testing voice-activated recording...".postln;

	// First make sure paths are set
	if (~humanVoicesDir.isNil) {
		"Please run ~initSoundPaths.() first!".postln;
		^nil;
	};

	~initRecording.();
	~setRecordingThreshold.(0.03, 1.5);
	~startVoiceActivatedRecording.();
};
)

// First, set up paths (this should already work)
~initSoundPaths.();

// Then initialize recording
~initRecording.();

// Start recording - will save to existing realVoices folder
~startVoiceActivatedRecording.();

// Speak into microphone...
// File will be saved to: data/realVoices/voice_TIMESTAMP.wav