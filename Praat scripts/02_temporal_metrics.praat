# Extract speech-time slope, mean pause duration and total pause time.
# Speech-time slope and mean pause definitions match the preceding version.
# Analyze a speech/pause interval tier (default: tier 1).
# Exact lowercase "speech" is speech; "pause" and empty labels are pause.
# strict_labels = yes rejects other labels. With strict_labels = no, every
# non-speech label is treated as pause, matching the supplied script.
# Use the first 60 s relative to the TextGrid start. Clip any later content.
# For shorter TextGrids, count the unobserved tail up to 60 s as pause.
# Merge contiguous pauses, including initial and final pause episodes.
# Total pause time sums all pause durations in the analysis window, in seconds.
# With no pause episodes: mean is blank and total pause time is zero.
# Slope is OLS against bin indices 1..4: seconds of speech per 15-s-bin step.
# CSV separator: semicolon; decimal point: dot. Input TextGrids are unchanged.

form 02_temporal_metrics
    sentence input_folder
    sentence output_file metrics_slope_mean_total_pause.csv
    natural tier_number 1
    boolean strict_labels 1
    boolean overwrite_existing 0
    comment Leave input_folder blank to select a folder after clicking OK.
    comment A filename-only output is saved inside the input folder.
    comment The selected tier must contain speech/pause labels, not words.
endform

analysis_window = 60
epsilon = 0.000000001

if input_folder$ = ""
    input_folder$ = chooseDirectory$: "Select the folder containing corrected TextGrids"
endif
if input_folder$ = ""
    exitScript: "Select the folder containing the TextGrids."
endif
if right$(input_folder$, 1) <> "/"
    input_folder$ = input_folder$ + "/"
endif
if index(output_file$, "/") = 0 and index(output_file$, "\") = 0
    output_file$ = input_folder$ + output_file$
endif
if fileReadable(output_file$) and overwrite_existing = 0
    exitScript: "Output already exists. Choose another filename or enable overwrite_existing: ", output_file$
endif
if right$(output_file$, 4) <> ".csv"
    exitScript: "output_file must end in .csv; do not select a TextGrid as output."
endif

Create Strings as file list: "files_3metrics", input_folder$ + "*.TextGrid"
file_list_id = selected("Strings")
numberOfFiles = Get number of strings
if numberOfFiles = 0
    removeObject: file_list_id
    exitScript: "No .TextGrid files found in the folder: ", input_folder$
endif

results$ = "file;speech_time_slope_15s;mean_pause_s;total_pause_s" + newline$
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
    
        total_pause = 0
        pause_count = 0
        unusual_this_file = 0
    
        speech_bin1 = 0
        speech_bin2 = 0
        speech_bin3 = 0
        speech_bin4 = 0
    
        pause_open = 0
        current_pause_start = 0
        current_pause_end = 0
    
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
    
                dur = clip_finish - clip_start
    
                if dur > 0
                    is_pause = 0
                    if label$ <> "speech"
                        is_pause = 1
                        if label$ <> "pause" and label$ <> ""
                            unusual_labels = unusual_labels + 1
                            unusual_this_file = unusual_this_file + 1
                        endif
                    endif
    
                    if is_pause = 1
                        if pause_open = 0
                            pause_open = 1
                            current_pause_start = clip_start
                            current_pause_end = clip_finish
                        else
                            if clip_start <= current_pause_end + epsilon
                                if clip_finish > current_pause_end
                                    current_pause_end = clip_finish
                                endif
                            else
                                pause_count = pause_count + 1
                                pause_duration[pause_count] = current_pause_end - current_pause_start
                                total_pause = total_pause + pause_duration[pause_count]
                                current_pause_start = clip_start
                                current_pause_end = clip_finish
                                pause_open = 1
                            endif
                        endif
                    else
                        if pause_open = 1
                            pause_count = pause_count + 1
                            pause_duration[pause_count] = current_pause_end - current_pause_start
                            total_pause = total_pause + pause_duration[pause_count]
                            pause_open = 0
                        endif
    
                        overlap_start = clip_start
                        if overlap_start < 0
                            overlap_start = 0
                        endif
                        overlap_end = clip_finish
                        if overlap_end > 15
                            overlap_end = 15
                        endif
                        overlap = overlap_end - overlap_start
                        if overlap > 0
                            speech_bin1 = speech_bin1 + overlap
                        endif
    
                        overlap_start = clip_start
                        if overlap_start < 15
                            overlap_start = 15
                        endif
                        overlap_end = clip_finish
                        if overlap_end > 30
                            overlap_end = 30
                        endif
                        overlap = overlap_end - overlap_start
                        if overlap > 0
                            speech_bin2 = speech_bin2 + overlap
                        endif
    
                        overlap_start = clip_start
                        if overlap_start < 30
                            overlap_start = 30
                        endif
                        overlap_end = clip_finish
                        if overlap_end > 45
                            overlap_end = 45
                        endif
                        overlap = overlap_end - overlap_start
                        if overlap > 0
                            speech_bin3 = speech_bin3 + overlap
                        endif
    
                        overlap_start = clip_start
                        if overlap_start < 45
                            overlap_start = 45
                        endif
                        overlap_end = clip_finish
                        if overlap_end > 60
                            overlap_end = 60
                        endif
                        overlap = overlap_end - overlap_start
                        if overlap > 0
                            speech_bin4 = speech_bin4 + overlap
                        endif
                    endif
                endif
            endif
        endfor
    
        if tg_duration < analysis_window
            clip_start = tg_duration
            clip_finish = analysis_window
    
            if pause_open = 0
                pause_open = 1
                current_pause_start = clip_start
                current_pause_end = clip_finish
            else
                if clip_start <= current_pause_end + epsilon
                    if clip_finish > current_pause_end
                        current_pause_end = clip_finish
                    endif
                else
                    pause_count = pause_count + 1
                    pause_duration[pause_count] = current_pause_end - current_pause_start
                    total_pause = total_pause + pause_duration[pause_count]
                    current_pause_start = clip_start
                    current_pause_end = clip_finish
                    pause_open = 1
                endif
            endif
        endif
    
        if pause_open = 1
            pause_count = pause_count + 1
            pause_duration[pause_count] = current_pause_end - current_pause_start
            total_pause = total_pause + pause_duration[pause_count]
        endif
    
        speech_time_slope_15s = (4 * (1 * speech_bin1 + 2 * speech_bin2 + 3 * speech_bin3 + 4 * speech_bin4) - 10 * (speech_bin1 + speech_bin2 + speech_bin3 + speech_bin4)) / 20
    
        # Mean duration of whole pause episodes, without splitting at bin boundaries.
        # total_pause already contains the sum of all pause durations in seconds,
        # including initial/final pauses and the retained short-tail convention.
        mean_pause$ = ""
        if pause_count > 0
            mean_pause = total_pause / pause_count
            mean_pause$ = string$(mean_pause)
        endif
    
        # Escape filenames so the CSV also supports quotes and semicolons.
        safe_file$ = replace$(file$, """", """""", 0)
        row$ = """" + safe_file$ + """" + ";" + string$(speech_time_slope_15s) + ";" + mean_pause$ + ";" + string$(total_pause)
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
appendInfoLine: "Columns: file; speech_time_slope_15s; mean_pause_s; total_pause_s."
appendInfoLine: "No pause episodes: mean is blank and total is zero. Input TextGrids were not changed."
if unusual_labels > 0
    appendInfoLine: ""
    appendInfoLine: "WARNING: ", unusual_labels, " labels other than speech/pause/empty were treated as PAUSE, matching the supplied script."
    appendInfoLine: "Check that the selected tier contains speech/pause timing labels, not transcribed words."
    appendInfoLine: unusual_files$
endif

if short_files > 0
    appendInfoLine: "WARNING: ", short_files, " TextGrids are shorter than 60 s. Missing tails were treated as pause, not observed audio."
endif
if long_files > 0
    appendInfoLine: "NOTE: ", long_files, " TextGrids exceed 60 s. Later content was excluded."
endif
