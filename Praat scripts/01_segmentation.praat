# Automatic intensity-based speech/pause segmentation.
# Creates an initial TextGrid for mandatory manual review.
# Default analysis settings match the supplied analysis script.
# No speech recognition, participant data or personal paths are included.

form Automatic_segmentation
    sentence input_file
    sentence output_file
    real silence_threshold -18
    real minimum_pause 0.30
    real minimum_sounding 0.25
    boolean overwrite_existing 0
    comment Leave input_file blank to select a WAV file after clicking OK.
    comment Leave output_file blank to save beside the audio as basename.TextGrid.
endform

if minimum_pause < 0 or minimum_sounding < 0
    exitScript: "Minimum interval durations must be nonnegative."
endif

if input_file$ = ""
    input_file$ = chooseReadFile$: "Select a WAV audio file"
endif
if input_file$ = ""
    exitScript: "Cancelled. No files were changed."
endif
if not fileReadable(input_file$)
    exitScript: "Cannot read the input audio file: ", input_file$
endif
if output_file$ = ""
    # Remove the final extension, not dots within the folder path.
    last_dot = rindex(input_file$, ".")
    last_slash = rindex(input_file$, "/")
    last_backslash = rindex(input_file$, "\")
    if last_dot > last_slash and last_dot > last_backslash
        output_file$ = left$(input_file$, last_dot - 1) + ".TextGrid"
    else
        output_file$ = input_file$ + ".TextGrid"
    endif
endif
if right$(output_file$, 9) <> ".TextGrid"
    exitScript: "The output filename must end in .TextGrid."
endif
if fileReadable(output_file$) and overwrite_existing = 0
    exitScript: "Output already exists. Choose another filename or enable overwrite_existing: ", output_file$
endif

Read from file: input_file$
sound_id = selected("Sound")

# Pitch floor = 100 Hz; time step = 0 (Praat automatic setting).
# The threshold is relative to the recording's maximum intensity.
To TextGrid (silences): 100, 0, silence_threshold, minimum_pause, minimum_sounding, "pause", "speech"
textgrid_id = selected("TextGrid")
Save as text file: output_file$

# Remove only the two objects created by this run, using their numeric IDs.
removeObject: sound_id, textgrid_id
writeInfoLine: "Saved initial segmentation: ", output_file$
appendInfoLine: "Listen to the audio and manually review every boundary and label before metric extraction."
