---
name: davinci-resolve
description: >
  Inspect, edit and render DaVinci Resolve projects by scripting the running Resolve Studio app
  through its Python API: read the media pool and timelines, look at footage via exported frames
  and contact sheets, build and recut timelines (append, trim, move, delete, markers, tracks,
  transitions, effects, titles), transcribe audio, and queue renders. Use whenever the user asks
  to do or check anything in DaVinci Resolve or a Resolve project, timeline, bin or export, e.g.
  "make a rough cut of these clips", "cut the dead air", "add markers where X happens", "what's on
  my timeline", "render this for YouTube", or any video-editing request where Resolve is the editor.
---

# DaVinci Resolve

Resolve Studio accepts Python scripts from outside the app. Scripts drive the **running**
instance and every change shows up live in the user's UI, on their real project, with live save on.

## Connect

Run Python through `bin/resolve-python` (sets the three env vars Resolve needs, then `exec python3`):

```bash
bin/resolve-python - <<'EOF'
import DaVinciResolveScript as dvr
resolve = dvr.scriptapp("Resolve")          # None if Resolve isn't running / scripting is off
project = resolve.GetProjectManager().GetCurrentProject()
pool, tl = project.GetMediaPool(), project.GetCurrentTimeline()
EOF
```

`scriptapp` returns `None` when Resolve isn't running or Preferences > System > General >
"External scripting using" isn't `Local`. Ask the user to fix either; don't launch or quit Resolve.

Start every task with `bin/resolve-inspect`: project, all timelines, and each clip on the current
timeline with its frame numbers. `-t NAME` details another timeline, `--media` lists every media
pool clip with its file path, `--json` gives the same data as JSON.

## API reference

The API is large and changes every release, so don't write calls from memory. Look them up in
`/opt/resolve/Developer/Scripting/`:

- `DaVinciResolveScript.pyi`: authoritative typed stubs with docstrings (3.6k lines, so grep it:
  `grep -n 'def .*Marker' …`, `grep -n '^class '`, `grep -n -A14 'class RenderSettings'`).
  Option dicts are the `TypedDict` classes at the top; methods are on `Resolve`, `ProjectManager`,
  `Project`, `MediaPool`, `MediaPoolItem`, `Folder`, `Timeline`, `TimelineItem`, `Graph`, `Effect`.
- `CHANGELOG.md`: what each version added. `Examples/`: short working scripts. `README.md`: overview.

## Look at the footage

Resolve renders stills for you; write them to a file and Read the image.

```python
clip.ExportThumbnails([{"frameOffset": f, "label": f"f{f}"} for f in range(0, n, n // 12)],
                      {"outputType": "file", "filePath": "/abs/sheet.jpg", "maxDimension": 1600, "quality": 80})
tl.ExportFrame(offset, {"outputType": "file", "filePath": "/abs/frame.jpg", "maxDimension": 960})
```

Both exist on `MediaPoolItem` (source frames), `Timeline` and `TimelineItem`. A labelled contact
sheet of 12 frames takes under a second, so survey a clip that way before choosing cut points, and
export frames again after an edit to confirm it. For speech, see `TranscribeAudio` /
`GetTranscription` (non-blocking; not exercised yet on this machine). For anything Resolve doesn't
expose, run `ffprobe`/`ffmpeg` on the clip's `File Path`.

## Frame numbers

- **Timeline positions are absolute and don't start at 0.** `tl.GetStartFrame()` is the 01:00:00
  start (215784 at 59.94 drop-frame, not 216000), so always read it. Absolute: item
  `GetStart/GetEnd`, `recordFrame`, `MoveItems`/`SetPosition` `startFrame`, render `MarkIn/MarkOut`.
- **Offsets from the timeline start (0-based):** `ExportFrame`/`ExportThumbnails` on a timeline,
  and marker `frameId`.
- Source ranges are `startFrame` inclusive, `endFrame` exclusive: 600 and 900 give 300 frames.
- `GetSourceStartFrame/EndFrame` came back off by one at 59.94 fps. Use `GetLeftOffset()` (frames
  into the source) and `GetDuration()` instead, as `resolve-inspect` does.
- Many values come back as strings (`'1920'`, `'570'`); convert before doing arithmetic.

## Editing behaviour (verified on 21.2)

- Edit only the **current** timeline: call `project.SetCurrentTimeline(tl)` first. `DeleteClips`
  failed on a non-current one. `CreateEmptyTimeline` and `DuplicateTimeline` both make the new
  timeline current, and creating one switches the UI to the Edit page.
- `pool.AppendToTimeline([{mediaPoolItem, startFrame, endFrame, recordFrame, trackIndex, mediaType}])`
  returns only the video items; linked audio lands on the audio track (`item.GetLinkedItems()`).
  `recordFrame` places a clip anywhere, leaving a gap if needed. `mediaType` 1 = video only, 2 = audio only.
- A `trackIndex` that doesn't exist does **not** create the track: the call still returns an item
  but nothing is added. Call `tl.AddTrack("video")` first.
- `SetLeftOffset/SetRightOffset` trim in place and leave a gap. `tl.DeleteGaps()` closes every gap
  on the timeline; use `tl.MoveItems` to close just one.
- `tl.DeleteClips(items, False)` leaves linked audio behind; pass `[item] + item.GetLinkedItems()`.
  With `True` (ripple) the linked audio went too.
- There is no blade. To split a clip, trim it and append the same source again for the other part.
- Failures return `False`, `None`, `''`, or a useless object instead of raising. Check each
  result, and re-run `resolve-inspect` after a batch of edits to confirm the timeline is as intended.

## Working on the user's project

- The API has no undo, and live save writes changes immediately. Before restructuring an existing
  timeline, `tl.DuplicateTimeline("<name> - before claude")` and switch back to the original, or do
  the work on a clearly named copy and say which.
- Only delete timelines, clips, bins and render jobs created in the current task. Never switch,
  close or delete projects, or quit Resolve, without being asked.
- The user is usually working in Resolve at the same time. Scripts switch pages and the current
  timeline under them, and calls that fail (a rejected render job, a clip that can't be placed)
  appear to raise warning dialogs that steal window focus. So say what is about to happen before a
  batch of edits, validate inputs instead of probing with calls that may fail, do the work in few
  runs, and put the page and current timeline back afterwards (`resolve.OpenPage(page)`).

## Rendering

```python
project.SetCurrentRenderFormatAndCodec("mp4", "H264_NVIDIA")   # or project.LoadRenderPreset("YouTube - 1080p")
project.SetRenderSettings({"TargetDir": "/home/xander/Videos", "CustomName": "name",
                           "SelectAllFrames": False, "MarkIn": t0, "MarkOut": t0 + 599})
job = project.AddRenderJob()                 # '' means rejected
project.StartRendering([job], False)
while project.IsRenderingInProgress(): time.sleep(1)
project.GetRenderJobStatus(job)              # {'JobStatus': 'Complete', ...}
```

Codec ids are hardware-specific: list them with `project.GetRenderCodecs("mp4")` (here
`H264_NVIDIA`, `H265_NVIDIA`, AV1; plain `"H264"` is refused). Presets: `GetRenderPresetList()`.
`AddRenderJob` returned `''` for a `TargetDir` under `/tmp`; a directory under the home folder or
the project's media drive worked. Rendering switches the UI to Deliver.
