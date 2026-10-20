# Extract speech duration only in four consecutive 15-second bins.
# Analyze a speech/pause interval tier (default: tier 1).
# Exact lowercase "speech" is speech; "pause" and empty labels are pause.
# strict_labels = yes rejects any other labels in the selected tier.
# With strict_labels = no, non-speech labels add no speech duration.
# Analyze [0,60) relative to the TextGrid start: [0,15), [15,30),
# [30,45), [45,60). Content after 60 s is excluded.
# Shorter TextGrids contribute zero speech in their missing tail.
# Split speech duration across bin boundaries by temporal overlap.
# Input and output paths are never read from remembered form fields.
# Every run asks the user to select the input folder explicitly.
# Output: speech_time_15s.csv in that folder. Input TextGrids are unchanged.
# CSV separator: semicolon; decimal point: dot. Durations are in seconds.

form Speech_time_per_bin_only_v2
    natural tier_number 1
    boolean strict_labels 1
    boolean overwrite_existing 0
    comment After OK, select the folder containing corrected TextGrids.
    comment Output: speech_time_15s.csv inside the selected folder.
    comment The selected tier must contain speech/pause labels, not words.
endform

analysis_window = 60
bin_width = 15
number_of_bins = 4

# Always open the folder picker. Do not reuse a cached input path.
input_folder$ = chooseDirectory$: "Select the folder containing corrected TextGrids"
if input_folder$ = ""
    exitScript: "Cancelled. No files were changed."
endif
if right$(input_folder$, 1) <> "/"
    input_folder$ = input_folder$ + "/"
endif
output_file$ = input_folder$ + "speech_time_15s.csv"
if fileReadable(output_file$) and overwrite_existing = 0
    exitScript: "Output already exists. Enable overwrite_existing to replace it: ", output_file$
endif
if right$(output_file$, 4) <> ".csv"
    exitScript: "output_file must end in .csv; do not select a TextGrid as output."
endif

Create Strings as file list: "files_speech_4x15s", input_folder$ + "*.TextGrid"
file_list_id = selected("Strings")
numberOfFiles = Get number of strings
if numberOfFiles = 0
    removeObject: file_list_id
    exitScript: "No .TextGrid files found in the folder: ", input_folder$
endif

results$ = "file;speech_time_0_15_s;speech_time_15_30_s;speech_time_30_45_s;speech_time_45_60_s" + newline$
processed_files = 0
short_files = 0
long_files = 0
unusual_labels = 0
unusual_files$ = ""

for i from 1 to numberOfFiles
    selectObject: file_list_id
    file$ = Get string: i

    # Ignore macOS resource-fork files (._...), which are not TextGrids.
    if left$(file$, 2) <> "._"
        Read from file: input_folder$ + file$
        tg_id = selected("TextGrid")
        selectObject: tg_id

        tier = tier_number
        tier_count = Get number of tiers
        if tier > tier_count
            removeObject: tg_id, file_list_id
            exitScript: "Requested tier does not exist in: ", file$
        endif
        is_interval = Is interval tier: tier
        if not is_interval
            removeObject: tg_id, file_list_id
            exitScript: "The selected tier must be an interval tier: ", file$
        endif
        n = Get number of intervals: tier
        tg_start = Get start time
        tg_end = Get end time
        tg_duration = tg_end - tg_start
        if tg_duration < analysis_window
            short_files = short_files + 1
        elsif tg_duration > analysis_window
            long_files = long_files + 1
        endif
        unusual_this_file = 0

        for b from 1 to number_of_bins
            speech_time[b] = 0
        endfor

        for j from 1 to n
            label$ = Get label of interval: tier, j
            if strict_labels and label$ <> "speech" and label$ <> "pause" and label$ <> ""
                removeObject: tg_id, file_list_id
                exitScript: "Unexpected label in ", file$, ", interval ", j, ": ", label$, ". Expected speech, pause or empty. No CSV was written."
            endif
            start = Get starting point: tier, j
            finish = Get end point: tier, j

            rel_start = start - tg_start
            rel_finish = finish - tg_start

            if rel_finish > 0 and rel_start < analysis_window
                clip_start = rel_start
                if clip_start < 0
                    clip_start = 0
                endif
                clip_finish = rel_finish
                if clip_finish > analysis_window
                    clip_finish = analysis_window
                endif

                if clip_finish > clip_start
                    if label$ = "speech"
                        for b from 1 to number_of_bins
                            bin_start = (b - 1) * bin_width
                            bin_end = b * bin_width

                            # Duration: temporal intersection between the interval and the bin.
                            overlap_start = clip_start
                            if overlap_start < bin_start
                                overlap_start = bin_start
                            endif
                            overlap_end = clip_finish
                            if overlap_end > bin_end
                                overlap_end = bin_end
                            endif
                            overlap = overlap_end - overlap_start
                            if overlap > 0
                                speech_time[b] = speech_time[b] + overlap
                            endif

                        endfor
                    else
                        if label$ <> "pause" and label$ <> ""
                            unusual_labels = unusual_labels + 1
                            unusual_this_file = unusual_this_file + 1
                        endif
                    endif
                endif
            endif
        endfor

        # Escape filenames so the CSV also supports quotes and semicolons.
        safe_file$ = replace$(file$, """", """""", 0)
        row$ = """" + safe_file$ + """"
        for b from 1 to number_of_bins
            row$ = row$ + ";" + string$(speech_time[b])
        endfor
        results$ = results$ + row$ + newline$
        processed_files = processed_files + 1

        if unusual_this_file > 0
            unusual_files$ = unusual_files$ + file$ + ": " + string$(unusual_this_file) + " unexpected labels" + newline$
        endif
        removeObject: tg_id
    endif
endfor

removeObject: file_list_id

if processed_files = 0
    exitScript: "No analyzable TextGrids in the folder. CSV was not changed."
endif
writeFile: output_file$, results$

writeInfoLine: "Completed: ", processed_files, " TextGrid."
appendInfoLine: "CSV: ", output_file$
appendInfoLine: "Output: file; 4 speech durations in seconds."
appendInfoLine: "Bins relative to the TextGrid start: 0-15, 15-30, 30-45, 45-60 s."
appendInfoLine: "Speech duration is split across bins by temporal overlap."
appendInfoLine: "Input TextGrids were not changed."
if unusual_labels > 0
    appendInfoLine: ""
    appendInfoLine: "WARNING: ", unusual_labels, " labels other than speech/pause/empty were treated as PAUSE, matching the supplied script."
    appendInfoLine: "Check that the selected tier contains speech/pause timing labels, not transcribed words."
    appendInfoLine: unusual_files$
endif

if short_files > 0
    appendInfoLine: "WARNING: ", short_files, " TextGrids are shorter than 60 s. Missing tails add zero speech duration."
endif
if long_files > 0
    appendInfoLine: "NOTE: ", long_files, " TextGrids exceed 60 s. Later content was excluded."
endif
