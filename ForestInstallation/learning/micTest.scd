ServerOptions.devices;

{
	//TODO: Presetting standard for objects

	s.options.inDevice = "MME : Auriculares (2- JBL TUNE510BT)";
	s.options.outDevice = "MME : Microphone Array (Realtek(R) Au";
	s.options.numOutputBusChannels
	s.reboot;
}

s.boot;
;

s.meter;

/*x = {
	var sig;
	sig = In.ar(2!2); // Better to use SoundIn in order to work better with other computers
	//Out.ar(0, sig) //redundant
	}.play;
*/

/*x = {
	var sig, rmod;
	sig = SoundIn.ar(0!2); // 0!2 or 0,0 for double signal
	rmod = sig * SinOsc.ar(700);
	(sig + rmod) * 0.5 //mixed to be better understanded
	}.play;
*/

//x = {SoundIn.ar(0!2)}.play;

{
SynthDef.new(\mic, {
		arg in=0, out=0, deltime = 0.3, amp=1;
		var sig, delay;
		sig = SoundIn.ar(in!2) * amp;
		delay = DelayL.ar(sig, 0.5, deltime);
		Out.ar(out, sig);
}).add(action: { "SynthDef added".postln; x = Synth(\mic) });
}

s.sync;

x = Synth(\mic);

x.free;

Server.killAll;

// First boot the server if not already running
s.boot;

// Define and add the SynthDef - make sure this executes completely
(
SynthDef(\mic, {
    arg in=0, out=0, deltime=0.3, amp=1;
    var sig, delay;
    sig = SoundIn.ar(in!2) * amp;
    delay = DelayL.ar(sig, 0.5, deltime);
    Out.ar(out, sig);
}).add;
)

// Then create the synth after a short delay
(
SystemClock.sched(0.5, {
    x = Synth(\mic);
    "Synth created".postln;
    nil; // Important for sched
});
)

// To free later
(
x.free;
"Synth freed".postln;
)




s.status;

SynthDescLib.global.synthDescs.at(\mic).postcs;