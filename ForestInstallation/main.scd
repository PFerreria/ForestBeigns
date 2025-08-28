// ======================================================================================
//  Main File For Forest Beings Aster+ Project
// ======================================================================================

// Description
// Main file for controlling Forest Being installation: mainly the queue management and the mic recording

(
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
	{ SoundIn.ar(0!2) * 0.5 }.play;
	"Testing microphone input... (you should hear yourself)".postln;

	{ SinOsc.ar(440, 0, 0.2) * EnvGen.kr(Env.perc(0.01, 0.5), doneAction:2) }.play;
	"Testing speaker output... (you should hear a beep)".postln;
};
);





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

	"Background sounds:".postln;
	~backgroundBuffers.do { |buf, i|
		("  " + i + ": " + buf.numChannels + " channels, " +
			buf.sampleRate + " Hz, " + buf.duration.round(0.1) + "s").postln;
	};

	"AI voices:".postln;
	~aiVoicePaths.do { |path, i|
		Buffer.read(s, path, action: { |b|
			("  " + i + ": " + b.numChannels + " channels, " +
				b.sampleRate + " Hz, " + b.duration.round(0.1) + "s").postln;
			b.free;
		});
	};

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
			{ PlayBuf.ar(2, buf, rate: BufRateScale.kr(buf), loop: 1) * 0.8 }.play;
			("Playing BACKGROUND: [" ++ index ++ "] - " + buf.duration.round(0.1) + "s").postln;
		} {
			"Can't test: No background buffers loaded.".postln;
		};
	}
	{ type == \ai } {
		if (~aiVoicePaths.notEmpty) {
			var path = ~aiVoicePaths.wrapAt(index);
			Buffer.read(s, path, action: { |b|
				{ PlayBuf.ar(2, b, rate: BufRateScale.kr(b), doneAction: 2) * 1.0 }.play;
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
				{ PlayBuf.ar(2, b, rate: BufRateScale.kr(b), doneAction: 2) * 1.0 }.play;
				("Playing HUMAN VOICE: [" ++ index ++ "] " + b.duration.round(0.01) + "s").postln;
			});
		} {
			"Can't test: No human voice paths stored.".postln;
		};
	};
};

~checkStatus = {
	("Background buffers: " + ~backgroundBuffers.size).postln;
	("AI voice paths: " + ~aiVoicePaths.size).postln;
	("Human voice paths: " + ~humanVoicePaths.size).postln;
};
);







// QUEUE WITH LOOPS
(
~initQueue = {
	~voiceQueue = List.new;
	~isPlaying = false;
	~currentPlayer = nil;
	~queueActive = false;
	~bgPlayer = nil;
	~currentBgIndex = 0;
	"Queue system initialized".postln;
};

~startQueue = { |bgIndex = 0, bgVolume = 0.5|
	"Starting queue...".postln;
	~queueActive = true;
	~currentBgIndex = bgIndex;

	~startBackgroundCycling.(bgVolume);

	if (~voiceQueue.size == 0) {
		~populateRandomQueue;
	};

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

~startBackgroundCycling = { |bgVolume = 0.5|
	if (~bgPlayer.notNil) { ~bgPlayer.free; ~bgPlayer = nil; };

	if (~backgroundBuffers.notNil && {~backgroundBuffers.size > 0}) {
		var buf = ~backgroundBuffers[~currentBgIndex];
		var numChannels = buf.numChannels;

		~bgPlayer = {
			var sig = PlayBuf.ar(numChannels, buf, rate: BufRateScale.kr(buf), loop: 0, doneAction: 2);
			if (numChannels == 1) { sig = Pan2.ar(sig) };
			sig * bgVolume;
		}.play;

		("Background started: [" + ~currentBgIndex + "] - " +
			PathName(buf.path).fileName + " - " + buf.duration.round(0.1) + "s - " +
			numChannels + " channels").postln;

		SystemClock.sched(buf.duration, {
			if (~queueActive) {
				~currentBgIndex = (~currentBgIndex + 1) % ~backgroundBuffers.size;
				~startBackgroundCycling.(bgVolume);
			};
			nil;
		});
	} {
		"Warning: Could not start background".postln;
	};
};

~populateRandomQueue = {
	var currentSize = ~voiceQueue.size;

	if (~aiVoicePaths.notNil && {~aiVoicePaths.size > 0}) {
		~aiVoicePaths.do { |path, i|
			~voiceQueue.add([\ai, i, path]);
		};
	};

	if (~humanVoicePaths.notNil && {~humanVoicePaths.size > 0}) {
		~humanVoicePaths.do { |path, i|
			~voiceQueue.add([\human, i, path]);
		};
	};

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

        ("PLAYING: " + type + " [" + index + "] - " + PathName(path).fileName).postln;
        ~isPlaying = true;

        Buffer.read(s, path, action: { |buf|
            var duration, numChannels;

            if (buf.numChannels == 0) {
                ("ERROR: Buffer has 0 channels: " + path).postln;
                buf.free;
                ~isPlaying = false;
                SystemClock.sched(0.5, { ~processQueue.(); nil });
                ^nil;
            };

            duration = buf.duration;
            numChannels = buf.numChannels;

            ("   Channels: " + numChannels + ", Duration: " + duration.round(0.1) + "s").postln;

            ~currentPlayer = {
                var sig = PlayBuf.ar(numChannels, buf, rate: BufRateScale.kr(buf), doneAction: 2);
                if (numChannels == 1) { sig = Pan2.ar(sig) };
                sig * 1.0
            }.play;

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
                        "Still no voices available - retrying...".postln;
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

	if (~voiceQueue.size > 0) {
		"Next few items:".postln;
		~voiceQueue.copyRange(0, 2.min(~voiceQueue.size - 1)).do { |item, i|
			("  " + i + ": " + item[0] + " - " + PathName(item[2]).fileName).postln;
		};
	};
};
);






// MIC RECORDING
(
~initRecording = {
    ~isRecording = false;
    ~currentMode = \silence;
    ~currentFramePosition = 0;
    ~silenceThreshold = 0.03;
    ~maxSilenceTime = 2.0;
    ~noiseFloor = 0.005;
    ~silenceTimer = 0;
    ~currentTimestamp = nil;
    ~recordingBuffers = List.new;

    "Recording system initialized".postln;
};

~startVoiceActivatedRecording = {
    if (~isRecording) {
        "Already recording".postln;
        ^nil;
    };

    ~isRecording = true;
    ~silenceTimer = 0;
    ~currentFramePosition = 0;
    ~currentTimestamp = Date.getDate.stamp;
    ~currentMode = \silence;

    "Voice-activated recording started...".postln;

    ~recordingRoutine = Routine({
        var buffer;
        var recorder;
        var currentStartFrame = 0;
        var inputLevel, isActualSound, isSilent;
        var levelReceived;

        buffer = Buffer.alloc(s, s.sampleRate * 60, 2);
        ~recordingBuffers.add(buffer);

        recorder = {
            var input = SoundIn.ar([0, 1]);
            var inputLevel = Amplitude.kr(input).max;
            SendReply.kr(Impulse.kr(10), '/recording_level', [inputLevel]);

            RecordBuf.ar(input, buffer, recLevel: 1, preLevel: 0, run: 1, loop: 0);
            Silent.ar(2);
        }.play;

        while { ~isRecording } {
            inputLevel = 0;
            levelReceived = Condition.new;

            OSCFunc({ |msg|
                inputLevel = msg[3];
                levelReceived.test = true;
                levelReceived.signal;
            }, '/recording_level').oneShot;

            0.1.wait;
            levelReceived.wait;

            ~currentFramePosition = ~currentFramePosition + (s.sampleRate * 0.1);

            isActualSound = inputLevel > ~noiseFloor;
            isSilent = inputLevel < ~silenceThreshold;

            switch(~currentMode,
                \noise, {
                    if (isSilent && isActualSound.not) {
                        ~silenceTimer = ~silenceTimer + 0.1;

                        if (~silenceTimer >= ~maxSilenceTime) {
                            "Silence detected - saving recording".postln;
							~currentMode = \silence;
                            ~saveRecording.(buffer, currentStartFrame, ~currentFramePosition);
                            currentStartFrame = ~currentFramePosition;
                            ~silenceTimer = 0;
                        };
                    } {
                        if (isActualSound) {
                            ~silenceTimer = 0;
                        };
                    };
                },
                \silence, {
                    if (isActualSound) {
                        "Sound detected - starting to record".postln;
                        ~currentMode = \noise;
                        ~silenceTimer = 0;
                        currentStartFrame = ~currentFramePosition;
                    };
                }
            );
        };

        if (~currentMode == \noise && (~currentFramePosition - currentStartFrame) > (s.sampleRate * 0.5)) {
            ~saveRecording.(buffer, currentStartFrame, ~currentFramePosition);
        };

        recorder.free;
    }).play;

    ^~currentTimestamp;
};

~saveRecording = { |buffer, startFrame, endFrame|
    var numFrames = endFrame - startFrame;
    var duration = numFrames / s.sampleRate;
    var soundFile;

    if (numFrames > (s.sampleRate * 0.1)) {
        var filename = "voice_" ++ Date.getDate.stamp ++ ".wav";
        var path = ~humanVoicesDir +/+ filename;

        fork {
            buffer.write(path, "WAV", "int16", startFrame, numFrames, true);
            0.5.wait;

            soundFile = SoundFile.new;
            if (soundFile.openRead(path)) {
                ("Recording saved: " + filename + " (" + duration.round(0.1) + "s, " +
                 soundFile.numChannels + " channels)").postln;
                soundFile.close;

                if (~humanVoicePaths.isNil) { ~humanVoicePaths = List.new; };
                ~humanVoicePaths.add(path);
                ~addToQueue.(\human, ~humanVoicePaths.size - 1);
            } {
                ("ERROR: Could not save recording: " + path).postln;
            };
        };
    } {
        "Recording too short to save".postln;
    };
};

~stopRecording = {
    if (~isRecording.not) {
        "Not currently recording".postln;
        ^nil;
    };

    ~isRecording = false;

    if (~recordingRoutine.notNil) {
        ~recordingRoutine.stop;
        ~recordingRoutine = nil;
    };

    "Recording stopped".postln;
};

~setRecordingThreshold = { |threshold = 0.03, maxSilence = 2.0, noiseFloor = 0.005|
    ~silenceThreshold = threshold.max(0.001);
    ~maxSilenceTime = maxSilence.max(0.5);
    ~noiseFloor = noiseFloor.max(0.0001);
    ("Threshold: " + ~silenceThreshold + ", Noise floor: " + ~noiseFloor).postln;
    ("Max silence time: " + ~maxSilenceTime + "s").postln;
};

~toggleRecording = {
    if (~isRecording) {
        ~stopRecording.();
    } {
        ~startVoiceActivatedRecording.();
    };
};

~addToQueue = { |type, index|
    var path;
    case
    { type == \ai } { path = ~aiVoicePaths.wrapAt(index); }
    { type == \human } { path = ~humanVoicePaths.wrapAt(index); };

    if (path.notNil) {
        ~voiceQueue.add([type, index, path]);
        ("Added " + type + " [" + index + "] to queue: " + PathName(path).fileName).postln;
    };
};

~cleanupRecording = {
    if (~isRecording) { ~stopRecording.(); };
    ~recordingBuffers.do(_.free);
    ~recordingBuffers.clear;
};
);

)





// ==================== USAGE ====================


~setupServer.();
~bootServer.();
//~testAudioIO.();
~initSoundPaths.();
~loadSoundsDirect.();
~cleanupRecording.();
~initRecording.();
~debugInputLevels.();
~setRecordingThreshold.(0.03, 2.0, 0.005);
~initQueue.();
~populateRandomQueue.();
~queueStatus.();
~startVoiceActivatedRecording.();
~startQueue.(0, 0.15);

// ============================== TEST FUNCTIONS ==================================
~testPlayback.();
~testPlayback.(\ai, 0);      // AI voice
~testPlayback.(\human, 5);   // Human voice
~checkStatus.();
~checkAudioProperties.();