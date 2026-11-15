# Contract: time and tour actions (feature 106)

Actions add `time.play [0…1]`, `time.rate [0…3]`, `date.set [−18,262.5…18,627.5]`, `tour.start [0…1]`, `tour.next`,
`tour.pause [0…1]`, `tour.stop`, `view.apply [7 values]`. Refusals: non-whole play/rate/tour values
`a14.invalid-choice`; tour actions without a tour `a14.no-tour`; `view.apply` with a value off its range
`a14.out-of-range`. Body choices (`body.select/next/previous`) during a tour stop the tour. Manifest: schema 4;
fixtures add `fixture-play-year` (rate 3 for 120 steps: day 365) and `fixture-tour-inner` (tour 0 after 600 steps:
Mercury).

Controls: Play/Pause (value playing or paused), Rate picker, Now, the tour menu (Inner planets, Giant planets),
Next stop, Pause tour, Stop tour, Save view, Restore view; each labelled with a value. Overlay: labels and the caption.
