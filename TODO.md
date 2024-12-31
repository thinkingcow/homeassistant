# Issues / TODO (incomplete)

## Introduction
Unlike the cloud based assistants that attempt natural language processing
on free form speech input, Rhasspy accepts a (potentially large) fixed
list of sentences to recognize.  This makes the speech recognition task
much easier, and the resultant actions more predictable, at the expense
of having a pre-determined sst of tasks and ways to invoke them.

## General Issues (in arbitrary order)
- The wake word is too sensitive.  Lots of false positives; no false
  negatives.  Even when recognition succeeds, the subsequent speech to text
  fails.  Should be mostly fixable by playing with the tuning parameters
- The "conference mic" is subject to crosstalk.  It works great in
  a quiet room with a nearby speaker.  For far away speakers or lots
  of background noise - not so well.  It should be possible to create
  a speaker array that detects the voice direction (e.g. from the wake
  word) to mitigate both issues.  I don't really want to build my own,
  'cause I'd be stuck maintaining it, and debugging DSP code is a pain.
  The only "hackable" ones I can currently find seem to be abandonware.
- The system will inevitably make mistakes: the voice command set
  should be designed to make corrections and "undo" as seamless as possible.
- The built-in tts (nanotts) is fast, but the voice quality is poor.
  The newly released "mimic3" is much higher quality, but even on an
  overclocked PI4, too slow for realtime use.  I could run mimic3 on a
  dedicated fast machine (which kind of defeats the purpose), or redesign
  all the dialogs, breaking them into chunks with pre-cached utterances to
  "hide" the delays.  I've done that successfully in the distant past
  (insert link here), but it's a pain.  So I'm back to nano-tts for now.
- I haven't figured out how the Fsticuffs Failure token works.  I want
  to say "oops" and have the "recognition failure" token play immediately.
- I should probably review the list of stop words `stop_words.txt`
  and tune it to the sentences I can recognise
- I need to write a suite of integration tests for the timers - it's
  getting too complicated to find bugs by inspection.
- It would be nice to have an "any" word - e.g. an arbitrary name for a
  timer.  Don't care what it is, as long as I can correlate the same word in
  a future utterance.  I'm currently faking it with a very large word
  list.  I can see how to do this conceptually, but I'm hoping someone
  else will beat me to it.
- I currently start each recognition task via screen.  This provides
  both protection from unepected signals, and the ability to look at the
  task logs easily by connection to the screen session.  Perhaps a nice
  systemd integration would be better.  Not sure yet.
