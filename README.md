# Verbal-fluency-Praat-scripts
Praat scripts for audio segmentation and temporal analysis of verbal fluency 

This repository contains three Praat scripts for automatic speech/pause segmentation and extraction of temporal metrics from manually corrected TextGrid annotations.

The scripts use **Praat scripting language** and run directly in Praat. 

## 1. Purpose of each script

| Script | Purpose |
| --- | --- |
| `01_segmentation.praat` | Create an initial speech/pause TextGrid from an audio recording. |
| `02_temporal_metrics_total_pause.praat` | Extract speech-time slope, mean pause duration and total pause time from corrected TextGrids. |
| `03_speech_time_per_bin.praat` | Extract speech duration in four consecutive 15-second bins from corrected TextGrids. |

Automatic segmentation must be reviewed manually before extracting metrics.

## 2. Required inputs

### Script 1: audio recording

`01_segmentation.praat` requires one audio file, preferably in WAV format.

Prepare the recording so that its start corresponds to the intended task onset. Retain the audio for manual review of the resulting annotations.

### Scripts 2 and 3: corrected TextGrids

The extraction scripts require a folder containing manually corrected `.TextGrid` files.

The scripts process files directly inside the selected folder and do not search subfolders. Use the exact `.TextGrid` extension for portability across operating systems.

Each TextGrid must contain a speech/pause **interval tier** spanning the full TextGrid duration. By default, the scripts analyse **tier 1**. Change `tier_number` if the relevant annotations are in another tier.

Labels are case-sensitive:

| Label | Interpretation |
| --- | --- |
| `speech` | Speech |
| `pause` | Pause |
| Empty label | Pause |

The selected tier must contain temporal speech/pause annotations.

With `strict_labels` enabled, unexpected labels stop the analysis. 

Audio files are not required for metric extraction from corrected TextGrids.

## 3. How to run the scripts

1. Download and extract the repository files.
2. Open Praat.
3. In the **Praat Objects** window, choose **Praat > Open Praat script...**.
4. Open the required `.praat` file.
5. In the Script Editor, choose **Run > Run**.
6. Follow the instructions below for the selected script.

### Script 1: automatic segmentation

Open `01_segmentation.praat`.

- Leave `input_file` blank to choose an audio file after clicking **OK**, or enter its full path.
- Leave `output_file` blank to save the TextGrid beside the audio. For example, `example.wav` produces `example.TextGrid`.
- Alternatively, specify a full output path ending in `.TextGrid`.

Default segmentation settings:

| Parameter | Default |
| --- | ---: |
| Pitch floor for intensity estimation | 100 Hz |
| Time step | 0: automatic |
| Silence threshold | −18 dB |
| Minimum pause interval | 0.30 s |
| Minimum sounding interval | 0.25 s |

The silence threshold is relative to the recording’s maximum intensity.

The script uses Praat’s `To TextGrid (silences)` command. Adjust the parameters when required by recording quality and report the settings used in the study.

After segmentation, open the Sound and TextGrid together in Praat. Listen to the recording, correct boundaries and labels, and save the reviewed TextGrid.

### Script 2: temporal metrics

Open `02_temporal_metrics_total_pause.praat`.

- Leave `input_folder` blank to select the folder of corrected TextGrids after clicking **OK**, or enter its full path.
- Keep `output_file` as `metrics_slope_mean_total_pause.csv` to save the CSV inside the selected input folder.
- Alternatively, enter a full absolute output path.
- Keep `tier_number = 1` if the first tier contains the speech/pause annotations.
- Keep `strict_labels` enabled.

A filename without a directory is saved inside the input folder. If specifying another output location, use a full absolute path. The destination folder must already exist.

### Script 3: speech duration per bin

Open `03_speech_time_per_bin.praat`.

- The settings window is titled **Speech_time_per_bin_only_v2**.
- Check `tier_number`, `strict_labels` and `overwrite_existing`.
- Click **OK**, then select the folder containing the corrected TextGrids.
- The script requests a folder explicitly on every run.
- The output is saved as `speech_time_15s.csv` inside that folder.

The folder-selection dialog may initially show a previously visited location. Navigate to the intended input folder and confirm it.

### Existing output files

All three scripts protect existing output files by default. Enable `overwrite_existing` only when replacement is intended.

## 4. Outputs and metric definitions

### Script 1

One `.TextGrid` containing the initial `speech` and `pause` intervals.

### Script 2

Output filename: `metrics_slope_mean_total_pause.csv`.

| Column | Description |
| --- | --- |
| `file` | Input filename |
| `speech_time_slope_15s` | Linear slope of speech duration across four 15-second bins |
| `mean_pause_s` | Mean duration of contiguous pause episodes, in seconds |
| `total_pause_s` | Total pause duration within the analysis window, in seconds |

#### Analysis window

The analysis covers the first **60 seconds relative to the TextGrid start**. Content after 60 seconds is excluded.

The analysis origin is the TextGrid start, so the task window must be aligned correctly during preparation.

#### Speech-time slope

The 60-second window is divided into four bins:

- 0–15 seconds
- 15–30 seconds
- 30–45 seconds
- 45–60 seconds

Speech duration is summed within each bin. A linear regression is then calculated using bin indices 1, 2, 3 and 4.

For speech-time sums `y1`, `y2`, `y3` and `y4`, the slope is:

```text
slope = (4 * (y1 + 2*y2 + 3*y3 + 4*y4) - 10 * (y1 + y2 + y3 + y4)) / 20
```

The unit is **seconds of speech per increment of one 15-second bin**.

A negative slope indicates decreasing speech duration across the task. A slope near zero indicates a relatively flat profile, while a positive slope indicates increasing speech duration.

To express the coefficient against elapsed time in seconds, divide this coefficient by 15.

#### Pause metrics

Initial and final pauses are included.

Adjacent pause-labelled or empty intervals are combined into contiguous pause episodes before calculating mean pause duration. Pause episodes are not split at bin boundaries.

Total pause time is the sum of pause durations within the analysis window. 

If there are no pauses:

- `mean_pause_s` is blank.
- `total_pause_s` is zero.

#### Recordings shorter than 60 seconds

The script retains the convention that a missing tail is treated as pause up to 60 seconds.

For example, a TextGrid ending at 55 seconds contributes an additional five seconds of pause under this convention. This affects total pause time and may affect mean pause duration.


### Script 3

Output filename: `speech_time_15s.csv`.

| Column | Description |
| --- | --- |
| `file` | Input filename |
| `speech_time_0_15_s` | Speech duration from 0 to 15 seconds |
| `speech_time_15_30_s` | Speech duration from 15 to 30 seconds |
| `speech_time_30_45_s` | Speech duration from 30 to 45 seconds |
| `speech_time_45_60_s` | Speech duration from 45 to 60 seconds |

All durations are in seconds relative to the TextGrid start.

Speech crossing a bin boundary is allocated according to its temporal overlap. For example, speech from 14 to 16 seconds contributes one second to each of the first two bins.

A bin containing no speech receives a value of zero. Missing time in recordings shorter than 60 seconds contributes zero speech duration.

### CSV format

- Column separator: semicolon.
- Decimal separator: point.
- One row per TextGrid.

Specify these settings when importing the CSV into spreadsheet or statistical software if they are not detected automatically.

## 5. Praat versions and validation

Initial standalone validation used **Praat 6.4.61 on 64-bit Linux**.

Additional checks, including regression checks of the total-pause and speech-duration-only revisions, used **Praat 6.1.38 embedded in Parselmouth 0.4.7**.

Parselmouth served as a testing tool. The distributed scripts run directly in Praat. 

## Data and scope

This repository contains no participant recordings or clinical data.

The scripts retain input filenames in the exported CSVs. 

The scripts perform temporal segmentation and feature extraction. 

## Documentation

- [Praat scripting manual](https://praat.org/manual/Scripting.html)
- [Sound: To TextGrid (silences)](https://praat.org/manual/Sound__To_TextGrid__silences____.html)
- [Praat file-selection dialogs](https://praat.org/manual/Scripting_6_6__Controlling_the_user.html)
