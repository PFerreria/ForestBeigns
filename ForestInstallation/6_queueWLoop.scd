// =============================================
// FIXED AUTOMATIC QUEUE WITH BACKGROUND CYCLING
// =============================================
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
)

(
~initQueue = {
	// Initialize the queue system
	~voiceQueue = List.new;
	~isPlaying = false;
	~currentPlayer = nil;
	~queueActive = false;
	~bgPlayer = nil;
	~currentBgIndex = 0; // Track current background index

	"Queue system initialized".postln;
};

// Modified startQueue with background cycling
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

// FIXED Background cycling function - handles both mono and stereo
~startBackgroundCycling = { |bgVolume = 0.5|
	if (~bgPlayer.notNil) { ~bgPlayer.free; ~bgPlayer = nil; };

	if (~backgroundBuffers.notNil && {~backgroundBuffers.size > 0}) {
		var buf = ~backgroundBuffers[~currentBgIndex];
		var numChannels = buf.numChannels; // Get the actual number of channels

		~bgPlayer = {
			var sig = PlayBuf.ar(numChannels, buf, rate: BufRateScale.kr(buf), loop: 0, doneAction: 2);
			// Convert mono to stereo if needed
			if (numChannels == 1) { sig = Pan2.ar(sig) };
			sig * bgVolume;
		}.play;

		("Background started: [" + ~currentBgIndex + "] - " +
			PathName(buf.path).fileName + " - " + buf.duration.round(0.1) + "s - " +
			numChannels + " channels").postln;

		// Schedule next background sound
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

// FIXED populate function - don't clear if already has items
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
		// Shuffle only the NEW items added, not the whole queue
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
		var silenceGap = 4.0; // seconds of silence between voices (adjust as needed)

		("🎵 NOW PLAYING: " + type + " [" + index + "] - " + PathName(path).fileName).postln;
		~isPlaying = true;

		Buffer.read(s, path, action: { |buf|
			var duration = buf.duration;
			var numChannels = buf.numChannels;

			("   Channels: " + numChannels + ", Duration: " + duration.round(0.1) + "s").postln;

			~currentPlayer = {
				var sig = PlayBuf.ar(numChannels, buf, rate: BufRateScale.kr(buf), doneAction: 2);
				// Convert mono to stereo if needed
				if (numChannels == 1) { sig = Pan2.ar(sig) };
				sig * 1.0
			}.play;

			// Schedule next voice with silence gap
			SystemClock.sched(duration + silenceGap, {
				~isPlaying = false;
				~currentPlayer = nil;
				buf.free; // Free the buffer after playing

				if (~queueActive) {
					// If queue is empty, repopulate it
					if (~voiceQueue.size == 0) {
						"Queue empty - adding more voices...".postln;
						~populateRandomQueue.();
					};

					// Continue with next item
					if (~voiceQueue.size > 0) {
						SystemClock.sched(0.5, { ~processQueue.(); nil });
					} {
						// If still empty, retry later
						"Still no voices available - retrying...".postln;
						SystemClock.sched(2.0, { ~processQueue.(); nil });
					};
				};
				nil;
			});
		});
	};
};

// Simple stop function
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

// Status function
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

// Simple environment starter
~startEnvironment = {
	"Starting environment...".postln;
	~initQueue.();
	~populateRandomQueue.(); // Populate FIRST
	~startQueue.(0, 0.4);   // Then start
};
)

// =============================================
// TEST SEQUENCE
// =============================================

// 1. First make sure sounds are loaded
~initSoundPaths.();
~loadSoundsDirect.();

// 2. Check what we have
("Background buffers: " + ~backgroundBuffers.size).postln;
("AI voices: " + ~aiVoicePaths.size).postln;
("Human voices: " + ~humanVoicePaths.size).postln;

~initQueue.();
~populateRandomQueue.();
~queueStatus.(); // Should show 6 voices

// 4. Start the system
~startQueue.(0, 0.15);

// 5. Check status after starting
~queueStatus.();

// Or use the simple one-command version:
~startEnvironment.();