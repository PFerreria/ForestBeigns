s.boot;

{SoundIn.ar(0!2)}.play;

// b = Buffer.read(s, "path/to/file.aiff"); //save to buffer and use
b = Buffer.alloc(s, s.sampleRate * 5); //alloc empty buffer for space an use

b.plot; //plot the buffer

b.zero; //clear buffer

(
x = {
	var sig;
	sig = SoundIn.ar(0);
	RecordBuf.ar(sig, b, \offset.kr(0),\reclev.kr(1), \prelev.kr(0), \run.kr(1), \loop.kr(1)); // reoord from sig to buffer b
	PlayBuf.ar(1!2, b, loop:1);
}.play;
)

(
x = {
	var sig, play;
	sig = SoundIn.ar(0);
	RecordBuf.ar(sig, b, \offset.kr(0),\reclev.kr(1), \prelev.kr(0), \run.kr(1), \loop.kr(1)); // reoord from sig to buffer b
	play = PlayBuf.ar(1!2, b, loop:1);
	play = HPF.ar(play, 80);
	play = LPF.ar(play, 12000);
}.play;
)

x.set(\reclev, 0, \prelev, 1);
x.set(\reclev, 1, \prelev, 0);
x.set(\reclev, 1, \prelev, -10.dbamp);

x.release(3);
x.free;

b.plot;
b.zero;
b.play;

Buffer.freeAll;
Server.killAll;


/////////////////////////////////////////////////////

//BufRd & BufRd
Buffer.freeAll;
b = Buffer.alloc(s, s.sampleRate * 3); //alloc empty buffer for space an use

(
SynthDef.new(\read, {
	var sig, ptr;
	ptr = Phasor.ar(\trig.tr(0), 1, 0, BufFrames.ir(\buf.ir(0)), 0);
	sig = BufRd.ar(1!2, \buf.ir(0), ptr);
	Out.ar(\out.ir(0), sig);
}).add;
)

(
SynthDef.new(\write, {
	var sig, ptr;
	sig = SoundIn.ar(0);
	ptr = Phasor.ar(\trig.tr(0), 1, 0, BufFrames.ir(\buf.ir(0)), 0);
	BufWr.ar(sig, \buf.ir(0), ptr);
}).add;
)

(
b.zero;
Synth(\read, [\buf, b]);
Synth(\write, [\buf, b]);
)

// or

(
b.zero;
Synth(\write, [\buf, b]);
Synth(\read, [\buf, b]);
)

b.plot;
b.play;

///////////////////////
Buffer.freeAll;
b = Buffer.alloc(s, s.sampleRate * 3);

(
x = {
	var sig;
	sig = SoundIn.ar(0);
	RecordBuf.ar(sig, b, \offset.kr(0),\reclev.kr(1).varlag(0.3), \prelev.kr(-3.dbamp.varlag(0.3)), \run.kr(1), \loop.kr(1)); // reoord from sig to buffer b
	PlayBuf.ar(1!2, b, 0.6, loop:1);
}.play;
)

x.set(\reclev, 0, \prelev, 1);
x.set(\reclev, 1, \prelev, 0);
x.set(\reclev, 1, \prelev, -10.dbamp);

x.release(3);

//////////////////////////////////

(
s.newBusAllocators;
~trigBus = Bus.audio(s,1);
~sweepBus = Bus.audio(s,1);
~ptrBus = Bus.audio(s,1);
~micBus = Bus.audio(s,1);
~micDirectBus = Bus.audio(s,1);
~loopBus = Bus.audio(s,1);
~mainOut = 0;
~micIn = 0;

s.waitForBoot({

	Buffer.freeAll;
	s.sync;

	~b = Buffer.alloc(s, s.sampleRate * 60);

	SynthDef(\mic, {
		var sig;
		sig = SoundIn.ar(\in.ir(0)) * \amp.kr(1);
		Out.ar(\outLoop.ir(0), sig);
		Out.ar(\outDirect.ir(0), sig);
	}).add;

	SynthDef(\trig, {
		var sig;
		sig = Trig1.ar(\trig.tr(0), ControlDur.ir);
		Out.ar(\out.ir(0), sig);
	}).add;

	SynthDef(\sweep, {
		var sig, trigSig;
		trigSig = In.ar(\inTrig.ir(0), 1);
		sig = Sweep.ar(\trig.tr(0) + trigSig, SampleRate.ir * \run.kr(1));
		Out.ar(\out.ir(0), sig);
	}).add;

	SynthDef(\ptr, {
		var sig, max, trigSig;
		trigSig = In.ar(\inTrig.ir(0), 1);
		max = In.ar(\inMax.ir(0), 1);
		sig = Phasor.ar(\trig.tr(0) + trigSig, 1, 0, max, 0);
		Out.ar(\out.ir(0), sig);
	}).add;

	SynthDef(\play, {
		var sig, ptr;
		ptr = In.ar(\inPtr.ir(0), 1);
		sig = BufRd.ar(1,\buf.kr(0),ptr);
		sig = sig * \amp.kr(1).varlag(\ampLag.kr(5),-2);
		Out.ar(\out.ir(0), sig);
	}).add;

	SynthDef(\rec, {
		var liveSig, loopSig, sig, ptr;
		ptr = In.ar(\inPtr.ir(0), 1);
		liveSig = In.ar(\inMic.ir(0), 1);
		loopSig = In.ar(\inLoop.ir(0), 1);
		sig = sum([
			liveSig * \liveAmp.kr(1).varlag(\ampLag.kr(5),-2),
			loopSig * \loopAmp.kr(1).varlag(\ampLag.kr(5),-2)
		]);
		sig = sig * \amp.kr(1).varlag(\ampLag.kr(5),-2);
		BufWr.ar(sig, \buf.kr(0), ptr);
	}).add;

	SynthDef(\mixer, {
		var loop, direct, sig;
		loop = In.ar(\inLoop.ir(0), 1);
		direct = In.ar(\inDirect.ir(0), 1);
		sig = sum([
			loop * \loopAmp.kr(1).varlag(\ampLag.kr(5),-2),
			direct * \directAmp.kr(1).varlag(\ampLag.kr(5),-2)
		]);
		sig = sig * \amp.kr(1).varlag(\ampLag.kr(5),-2);
		Out.ar(\out.ir(0), sig!2);
	}).add;

	s.sync;

	~micGrp = Group.new;
	~trigGrp = Group.after(~micGrp);
	~sweepGrp = Group.after(~trigGrp);
	~ptrGrp = Group.after(~sweepGrp);
	~playGrp = Group.after(~ptrGrp);
	~recGrp = Group.after(~playGrp);
	~mixerGrp = Group.after(~recGrp);


	s.sync;

	~micSynth = Synth(
		\mic, [
			\in, ~micIn,
			\outLoop, ~micBus,
			\outDirect, ~micDirectBus,
			\amp, 1
		], ~micGrp
	);

	~trigSynth = Synth(
		\trig, [
			\trig, 0,
			\out, ~trigBus,
		], ~trigGrp
	);

	~sweepSynth = Synth(
		\sweep, [
			\trig, 0,
			\inTrig, ~trigBus,
			\out, ~sweepBus,
			\run, 0,
		], ~sweepGrp
	);

	~ptrSynth = Synth(
		\ptr, [
			\trig, 0,
			\inTrig, ~trigBus,
			\inMax, ~sweepBus,
			\out, ~ptrBus,
		], ~ptrGrp
	);

	~playSynth = Synth(
		\play, [
			\inPtr, ~ptrBus,
			\out, ~loopBus,
			\buf, ~b.bufnum,
		], ~playGrp
	);

	~recSynth = Synth(
		\rec, [
			\inPtr, ~ptrBus,
			\inMic, ~micBus,
			\inLoop, ~loopBus,
			\buf, ~b.bufnum,
			\liveAmp, 0,
			\loopAmp, 0,
		], ~recGrp
	);

	~mixerSynth = Synth(
		\mixer, [
			\inLoop, ~loopBus,
			\inDirect, ~micDirectBus,
			\loopAmp, 1,
			\directAmp, 1,
			\amp, 1,
			\out, ~mainOut,
		], ~mixerGrp
	);
});
)

(
//initial start record
s.makeBundle(nil, {
	~trigSynth.set(\trig, 1);
	~sweepSynth.set(\run, 1);
	~recSynth.set(\liveAmp, 1, \loopAmp, 1, \amp, 1, \ampLag, 0.02);
	~playSynth.set(\amp, 1, \ampLag, 0.02);
	~mixerSynth.set(\loopAmp, 1, \liveAmp, 1);
})
)

(
//stop recording, play along with loop
~sweepSynth.set(\run, 0);
~recSynth.set(\liveAmp, 0, \loopAmp, 1);
)

(
//overdub
~sweepSynth.set(\run, 0);
~recSynth.set(\liveAmp, 1, \loopAmp, -1.dbamp);
)

(
//stop overdubbing
~recSynth.set(\liveAmp, 0, \loopAmp, 1);
)

//fade out playback via mixer Synth (does not affect buffer contents)
~mixerSynth.set(\loopAmp, 0, \ampLag, 3);

//fade in playback via mixer Synth
~mixerSynth.set(\loopAmp, 1, \ampLag, 3);

//fade in quickly and reset frame pointer (jump to buffer start)
(
~mixerSynth.set(\loopAmp, 1, \ampLag, 0.02);
~ptrSynth.set(\trig, 1);
)

//zero incoming signals, will eventually clear buffer once a full cycle is complete
~recSynth.set(\liveAmp, 0, \loopAmp, 0, \ampLag, 3);

//fade live signal back into recording input
~recSynth.set(\liveAmp, 1, \loopAmp, 0, \ampLag, 3);

(
//reset, clear buffer, do not resume recording again
s.makeBundle(nil, {
	~b.zero;
	~trigSynth.set(\trig, 1);
	~sweepSynth.set(\run, 0);
	~recSynth.set(\liveAmp, 0, \loopAmp, 0, \amp, 0, \ampLag, 0.02);
});
)

(
//reset, clear buffer, and immediately begin recording again
s.makeBundle(nil, {
	~b.zero;
	~trigSynth.set(\trig, 1);
	~sweepSynth.set(\run, 1);
	~recSynth.set(\liveAmp, 1, \loopAmp, 1, \amp, 1, \ampLag, 0.02);
	~playSynth.set(\amp, 1, \ampLag, 0.02);
	~mixerSynth.set(\loopAmp, 1, \liveAmp, 1);
});
)
