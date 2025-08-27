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
	s.options.memSize = 2.pow(20); // Enough memory for long buffers

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

// TEST in order
~setupServer.();    // Configure
~bootServer.();     // Boot
~testAudioIO.();    // Verify