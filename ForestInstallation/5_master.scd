// =============================================
// MASTER CONTROL & ENVIRONMENT MANAGEMENT
// =============================================

(
~initEnvironment = {
	// Master initialization function
	"=== INITIALIZING FOREST BEINGS ENVIRONMENT ===".postln;

	// Initialize all subsystems
	~initSoundPaths.();
	~loadSounds.();
	~initQueue.();
	~initRecording.();

	// Environment state
	~environmentActive = false;
	~currentBackgroundIndex = 0;
	~masterVolume = 0.7;

	"All subsystems initialized successfully".postln;
	"Use ~startEnvironment.() to begin".postln;
};

~startEnvironment = { |bgIndex = 0, bgVolume = 0.6|
	"=== STARTING ENVIRONMENT ===".postln;

	if (~environmentActive) {
		"Environment is already running".postln;
		^nil;
	};

	~environmentActive = true;
	~currentBackgroundIndex = bgIndex;

	// Start background sound
	~startQueue.(bgIndex, bgVolume);

	// Set recording sensitivity for voice detection
	~setRecordingThreshold.(0.04, 2.0);

	"🌿 Environment started successfully".postln;
	"🎤 Voice-activated recording ready".postln;
	"🎵 Background sound playing".postln;
	"💬 Queue system active".postln;
};

~stopEnvironment = {
	"=== STOPPING ENVIRONMENT ===".postln;

	~environmentActive = false;

	// Stop all subsystems
	~stopQueue.();
	~stopMonitoring.();

	"Environment stopped. All systems shut down".postln;
};

~pauseEnvironment = {
	"⏸️ Pausing environment...".postln;
	~stopQueue.();
	"Environment paused. Background and queue stopped".postln;
};

~resumeEnvironment = {
	"▶️ Resuming environment...".postln;
	~startQueue.(~currentBackgroundIndex, ~masterVolume);
	"Environment resumed".postln;
};

~setMasterVolume = { |volume = 0.7|
	~masterVolume = volume.clip(0, 1);
	~setBackgroundVolume.(volume);
	("Master volume set to: " + volume).postln;
};

~nextBackground = {
	var nextIndex = (~currentBackgroundIndex + 1) % ~backgroundBuffers.size;
	~changeBackground.(nextIndex);
};

~previousBackground = {
	var prevIndex = (~currentBackgroundIndex - 1) % ~backgroundBuffers.size;
	~changeBackground.(prevIndex);
};

~changeBackground = { |index|
	if (index.inclusivelyBetween(0, ~backgroundBuffers.size - 1)) {
		~currentBackgroundIndex = index;
		if (~environmentActive) {
			~startQueue.(index, ~masterVolume);
			("Changed to background: " + index).postln;
		};
	} {
		("Invalid background index: " + index).postln;
	};
};

~getStatus = {
	"=== ENVIRONMENT STATUS ===".postln;
	("Active: " + ~environmentActive).postln;
	("Background: " + ~currentBackgroundIndex + " of " + ~backgroundBuffers.size).postln;
	("Master Volume: " + ~masterVolume).postln;
	("Queue Items: " + ~voiceQueue.size).postln;
	("Recording: " + ~isRecording).postln;
	("AI Voices: " + ~aiVoicePaths.size).postln;
	("Human Voices: " + ~humanVoicePaths.size).postln;
};

~quickSetup = {
	"🚀 Quick environment setup...".postln;

	~initEnvironment.();

	SystemClock.sched(2, {
		// Add some initial AI voices
		if (~aiVoicePaths.size > 0) {
			~addToQueue.(\ai, 0);
			~addToQueue.(\ai, 0);
		};

		// Start everything
		~startEnvironment.(0, 0.6);

		"✅ Quick setup complete! Environment is running".postln;
		nil;
	});
};

~emergencyStop = {
	"🛑 EMERGENCY STOP - Shutting down everything".postln;

	// Force stop all possible processes
	~stopEnvironment.();
	~clearQueue.();

	if (~micMonitor.notNil) { ~micMonitor.free; ~micMonitor = nil; };
	if (~bgPlayer.notNil) { ~bgPlayer.free; ~bgPlayer = nil; };
	if (~currentPlayer.notNil) { ~currentPlayer.free; ~currentPlayer = nil; };
	if (~recorder.notNil) { ~recorder.free; ~recorder = nil; };

	Server.freeAll;
	"All audio processes stopped".postln;
};

// Preset system for different configurations
~presets = (
	\forest: { ~changeBackground.(0); ~setMasterVolume.(0.6); },
	\rain: { ~changeBackground.(1); ~setMasterVolume.(0.5); },
	\night: { ~changeBackground.(2); ~setMasterVolume.(0.4); },
	\quiet: { ~setRecordingThreshold.(0.02, 3.0); },
	\loud: { ~setRecordingThreshold.(0.08, 1.0); }
);

~loadPreset = { |presetName|
	if (~presets[presetName].notNil) {
		("Loading preset: " + presetName).postln;
		~presets[presetName].value;
	} {
		("Unknown preset: " + presetName).postln;
	};
};
)

// =============================================
// USER-FRIENDLY CONTROL FUNCTIONS
// =============================================

(
// Simple one-command control
~start = { ~quickSetup.(); };
~stop = { ~stopEnvironment.(); };
~pause = { ~pauseEnvironment.(); };
~resume = { ~resumeEnvironment.(); };

// Voice recording control
~record = { ~startVoiceActivatedRecording.(); };
~stopRecord = { ~stopRecording.(); };

// Queue management
~addAI = { |index = 0| ~addToQueue.(\ai, index); };
~addHuman = { |index = 0| ~addToQueue.(\human, index); };

// Status and info
~status = { ~getStatus.(); };
~vol = { |level| ~setMasterVolume.(level); };
~next = { ~nextBackground.(); };
~prev = { ~previousBackground.(); };
)

// =============================================
// AUTOMATIC ERROR RECOVERY
// =============================================

(
~watchdog = {
	// Simple watchdog to keep environment running
	Routine({
		inf.do {
			if (~environmentActive && ~bgPlayer.isNil) {
				"⚠️  Background stopped unexpectedly - restarting...".postln;
				~startQueue.(~currentBackgroundIndex, ~masterVolume);
			};
			5.wait; // Check every 5 seconds
		};
	}).play;

	"Watchdog started - automatic recovery enabled".postln;
};
)

// =============================================
// COMPLETE DEMO
// =============================================

(
~demo = {
	"🎪 Starting Forest Beings Demo...".postln;

	~initEnvironment.();

	SystemClock.sched(2, {
		// Setup
		~loadPreset.(\forest);
		~addAI.(0);
		~addAI.(0);

		// Start
		~startEnvironment.(0, 0.6);
		~watchdog.();

		// Demo sequence
		SystemClock.sched(10, {
			"🔊 Increasing volume...".postln;
			~setMasterVolume.(0.8);
			nil;
		});

		SystemClock.sched(20, {
			"🌙 Changing to night atmosphere...".postln;
			~loadPreset.(\night);
			nil;
		});

		SystemClock.sched(30, {
			"🎤 Demo recording starting...".postln;
			~startVoiceActivatedRecording.();
			nil;
		});

		"Demo started! Watch the post window for updates".postln;
		nil;
	});
};
)

// Quick start
~start.(); // Everything in one command

// Or manual control
~initEnvironment.();
~startEnvironment.(0, 0.6); // Start with background 0 at volume 0.6

// Simple controls
~vol.(0.5);    // Set volume to 50%
~next();       // Next background sound
~addAI.(0);    // Add AI voice to queue
~record();     // Start voice recording
~status();     // Check system status

// Presets
~loadPreset.(\night); // Night atmosphere
~loadPreset.(\quiet); // More sensitive recording