// =============================================
// SIMPLIFIED QUEUE WITHOUT SILENCE (FIXED SYNTAX)
// =============================================

(
~initQueue = {
	// Initialize the queue system
	~voiceQueue = List.new;
	~isPlaying = false;
	~currentPlayer = nil;
	~queueActive = false;
	~bgPlayer = nil;

	"Queue system initialized".postln;
};

// Simplified addToQueue
~addToQueue = { |type = \ai, index = 0|
	var item, path;

	// Check if voice paths are properly initialized
	if (~aiVoicePaths.isNil) { ~aiVoicePaths = List.new; };
	if (~humanVoicePaths.isNil) { ~humanVoicePaths = List.new; };

	case { type == \ai } {
		if (~aiVoicePaths.notNil && {~aiVoicePaths.size > index}) {
			path = ~aiVoicePaths[index];
			item = [type, index, path];
		} {
			("Error: AI voice index " + index + " not available. Available: " + ~aiVoicePaths.size).postln;
			^nil;
		};
	} { type == \human } {
		if (~humanVoicePaths.notNil && {~humanVoicePaths.size > index}) {
			path = ~humanVoicePaths[index];
			item = [type, index, path];
		} {
			("Error: Human voice index " + index + " not available. Available: " + ~humanVoicePaths.size).postln;
			^nil;
		};
	} {
		("Error: Unknown voice type '" + type + "'").postln;
		^nil;
	};

	~voiceQueue.add(item);
	("Added to queue: " + type + " [" + index + "] - " + ~voiceQueue.size + " items in queue").postln;

	if (~queueActive and: { ~isPlaying.not }) {
		~processQueue.();
	};

	^item;
};

// Simplified startQueue
~startQueue = { |bgIndex = 0, bgVolume = 0.7|
	"Starting queue with background...".postln;
	~queueActive = true;

	// Start background sound
	if (~bgPlayer.isNil && ~backgroundBuffers.notNil && {~backgroundBuffers.size > bgIndex}) {
		~bgPlayer = {
			var buf = ~backgroundBuffers[bgIndex];
			var sig = PlayBuf.ar(2, buf, rate: BufRateScale.kr(buf), loop: 1);
			var isPlayingNum = ~isPlaying.binaryValue;  // Convert false->0, true->1
			var duckFactor = 1 - (isPlayingNum * 0.5);
			sig * bgVolume * duckFactor;
		}.play;

		("Background started: [" + bgIndex + "] at volume " + bgVolume).postln;
	} {
		"Warning: Could not start background".postln;
	};

	// Start processing queue
	if (~voiceQueue.size > 0 && ~isPlaying.not) {
		~processQueue.();
	};
};

// FIXED processQueue - variables declared at top
~processQueue = {
	var nextItem, type, index, path;

	if (~queueActive and: { ~voiceQueue.size > 0 && ~isPlaying.not }) {
		~isPlaying = true;
		nextItem = ~voiceQueue.removeAt(0);
		type = nextItem[0];
		index = nextItem[1];
		path = nextItem[2];

		("Now playing: " + type + " [" + index + "] - " + ~voiceQueue.size + " items remaining").postln;

		Buffer.read(s, path, action: { |buf|
			var duration = buf.duration;

			~currentPlayer = {
				var sig = PlayBuf.ar(2, buf, rate: BufRateScale.kr(buf), doneAction: 2);
				sig * 0.8
			}.play;

			// Just wait for the clip to finish
			SystemClock.sched(duration + 5.0, {
				~isPlaying = false;
				~currentPlayer = nil;
				if (~queueActive and: { ~voiceQueue.size > 0 }) {
					~processQueue.();
				} {
					"Queue empty".postln;
				};
				nil;
			});
		});
	};
};

// Keep other functions simple
~stopQueue = {
	"Stopping queue and background...".postln;
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

~clearQueue = {
	"Clearing queue...".postln;
	~voiceQueue.clear;
	~stopQueue.();
};

~queueStatus = {
	"=== QUEUE STATUS ===".postln;
	("Queue active: " + ~queueActive).postln;
	("Currently playing: " + ~isPlaying).postln;
	("Background playing: " + ~bgPlayer.notNil).postln;
	("Items in queue: " + ~voiceQueue.size).postln;
	~voiceQueue.do { |item, i|
		("  " + i + ": " + item[0] + " [" + item[1] + "]").postln;
	};
};
)

// =============================================
// SIMPLE TEST FUNCTIONS
// =============================================
(
~testSimpleQueue = {
	"Testing simple queue...".postln;

	// Initialize if needed
	if (~voiceQueue.isNil) { ~initQueue.(); };

	// Add voices directly
	~addToQueue.(\ai, 0);
	~addToQueue.(\human, 0);
	~addToQueue.(\ai, 0);

	// Start everything
	~startQueue.(0, 0.7);
};

// Quick environment starter
~startSimpleEnvironment = {
	"Starting simple environment...".postln;

	~initSoundPaths.();
	~loadSounds.();
	~initQueue.();

	SystemClock.sched(2, {
		~addToQueue.(\ai, 0);
		~addToQueue.(\human, 0);
		~startQueue.(0, 0.7);
		"Simple environment started!".postln;
		nil;
	});
};
)

// First make sure sounds are loaded
~initSoundPaths.();
~loadSoundsDirect.();

// Wait a moment, then:
~initQueue.();
~addToQueue.(\ai, 0);
~addToQueue.(\human, 0); // With extra silence
~addToQueue.(\ai, 0);
~startQueue.(0, 0.7);

// Or use the automatic version:
~startEnvironment.();