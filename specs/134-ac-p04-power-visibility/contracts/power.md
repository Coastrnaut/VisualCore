# Contract: power and visibility (A18-P04)

- **Frame cap:** a session of Ambient Clock has `host.framePacing.maxFPS == 30` at nominal heat with Low Power Mode
  off. A session of another experience (a test presenter without a declaration) has 60. A declared 10 is raised to 30.
- **Night:**
  - with the window 22:00–07:00, `isNight` at 21:59, 22:00, 06:59 and 07:00 gives false, true, true and false;
  - with 13:00–14:00, 12:59 gives false, 13:00 true and 14:00 false; start = end is never night;
  - the night text reaches at least 4.5 : 1 against all dimmed palette colours;
  - a night frame is darker than the day frame (mean luma) and non-blank.
- **Brightness:** no source in `Packages/ExperiencesCreative/AmbientClock` contains `brightness =`.
- **Drift:**
  - |x|, |y| ≤ 8 for 1,440 sampled instants of a day (every 60 s);
  - consecutive minute samples differ by at most 6 points;
  - equal instants give equal offsets;
  - reduced motion gives (0, 0).
- **Dim:** 1 at 599 s after the last action, 0.6 at 600 s, and 1 again after a new action.
- **Keep-awake:**
  - with the setting off, the port is never set to true;
  - with it on, it becomes true at setup or `didBecomeActive`, and false at `willResignActive`,
    `didEnterBackground`, teardown and setting off;
  - `isIdleTimerDisabled` appears only in `Experience/KeepAwake.swift`.
- **Resume:** the display shows 2:05 PM; the clock moves to 2:35 PM; posting `willEnterForegroundNotification` shows
  2:35 PM with no draw.
- **Snapshot:** the schema-1 and schema-2 examples migrate to schema 3 with the defaults; schema 3 round-trips.
