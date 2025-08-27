// Clean state
Server.killAll;
s.quit;
0.5.wait;

// Configure server (add this before booting)
// TODO: Configure server for final version including mic and speaker requirements
s.options.maxLogins = 8;  // Allow multiple connections
s.options.bindAddress = "0.0.0.0"; // Alternative binding

// TODO: Make explicative legend
// Server with error handling
(
s.waitForBoot {
    // ========== SETUP ==========
    var mainStreamDir = "/path/to/main_stream/".standardizePath;
    var type1Dir = "/path/to/type1_sounds/".standardizePath;
    var type2Dir = "/path/to/type2_sounds/".standardizePath;

    ~mainStream = List.new;
    ~type1Queue = List.new;
    ~type2Pool = List.new;

    ~loadBuffers = {
        var loadFunc = { |path, list|
            PathName(path).entries.do { |file|
                try {
                    list.add(Buffer.read(s, file.fullPath));
                    ("Loaded:" + file.fileName).postln;
                } { |error|
                    ("Failed to load:" + file.fileName + error.what).postln;
                };
            };
        };

        loadFunc.(mainStreamDir, ~mainStream);
        loadFunc.(type1Dir, ~type1Queue);
        loadFunc.(type2Dir, ~type2Pool);

        s.sync;
    };

    // ========== PLAYBACK SYSTEM ==========
    SynthDef(\playBuf, { |buf, amp=0.7, out=0|
        var sig = PlayBuf.ar(1, buf, doneAction:2) * amp;
        Out.ar(out, sig ! 2);  // Stereo output
    }).add;

    s.sync;

    ~loadBuffers.();

    // Start player
    ~bgPlayer = Routine {
        inf.do { |i|
            var buf = ~mainStream.wrapAt(i);
            Synth(\playBuf, [\buf, buf, \amp, 0.4]);
            buf.duration.wait;
        };
    }.play;

    ~queuePlayer = Routine {
        var pos = 0;
        loop {
            if (~type1Queue.size > 0) {
                var buf = ~type1Queue[pos];
                Synth(\playBuf, [\buf, buf]);
                buf.duration.wait;
                pos = (pos + 1) % ~type1Queue.size;
            } {
                0.1.wait;
            };
        };
    }.play;

    // ========== QUEUE CONTROLS ==========
    ~insertRandom = {
        if (~type2Pool.size > 0 && ~type1Queue.size > 0) {
            var insertPos = rrand(1, max(1, ~type1Queue.size-1));
            var sound = ~type2Pool.choose;

            ~type1Queue.insert(insertPos, sound);
            ("Inserted at position" + insertPos).postln;
        } {
            "Cannot insert - check available sounds".postln;
        };
    };

    ~addToEnd = { |path|
        try {
            Buffer.read(s, path, action: { |buf|
                ~type1Queue.add(buf);
                ("Added:" + PathName(path).fileName).postln;
            });
        } { |error|
            ("Load failed:" + error.what).postln;
        };
    };

	// TODO: Queue control fails when executing type 2
	// TODO: Syntax correctness
	// TODO+: Add randomness to n!0 iterations of whole loop, type 1 always in same order

    "SYSTEM READY".postln;
    "Run ~insertRandom.() to insert random sounds".postln;
    "Run ~addToEnd(\"/path/to/sound.wav\") to queue sounds".postln;

    // Cleanup on server quit
    s.onFree = {
        ~bgPlayer.stop;
        ~queuePlayer.stop;
        [~mainStream, ~type1Queue, ~type2Pool].do { |list|
            list.do(_.free);
        };
    };
};
)