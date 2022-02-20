#!/usr/bin/env bash

if [ -t 1 ]
then
	progress_init_scroll()
	{
		# Current terminal height
		PROGRESS_LINES=$(tput lines)

		PROGRESS_SCROLL_LINES=$((PROGRESS_LINES - PROGRESS_BAR_LINES))

		# Scroll one line to avoid visual glitch when shrinking by one row
		tput cud1

		# Save cursor position
		tput sc

		# Set scroll region (and move cursor to the top-left corner)
		tput csr 0 "$PROGRESS_SCROLL_LINES"

		# Restore cursor position
		tput rc

		# Move the cursor up into the scroll-region
		tput cuu1

		progress_bar
	}

	progress_destroy_scroll()
	{
		local lines=$(tput lines)

		# Save cursor position
		tput sc

		# Reset scroll region (and move cursor to the top-left corner)
		tput csr 0 "$lines"

		# Restore cursor position
		tput rc

		# Clear progress bar
		progress_bar_clear

		# Insert empty line
		echo
	}

	progress_bar_part() # char count [prefix] [suffix]
	{
		local count="$2"

		if [ "$count" -gt 0 ]
		then
			local char="$1"
			local prefix="${3:-}"
			local suffix="${4:-}"

			[ "$char" == "%" ] && char="%%"

			echo -n "$prefix"
			printf "%.0s$char" $(seq 1 "$count")
			echo -n "$suffix"
		fi
	}

	progress_bar() # [step_name]
	{
		local step_name="${1:-}"
		local columns=$(tput cols)

		# Save cursor position
		tput sc

		# Go to the progress-bar region
		tput cup "$((PROGRESS_SCROLL_LINES + 1))" 0

		# Clear progress-bar
		tput ed

		# Print progress-bar
		local progress=$(bc -l <<< "scale = 2; $PROGRESS_CURR / $PROGRESS_TOTAL")

		local prefix=$(printf "%${PROGRESS_BAR_PREFIX_FW}s [" "$step_name")
		local suffix=$(printf "] %${PROGRESS_BAR_SUFFIX_FW}s" "$PROGRESS_CURR/$PROGRESS_TOTAL")

		local prefix_length=${#prefix}
		local suffix_length=${#suffix}

		local bar_length=$((columns - prefix_length - suffix_length))
		local filled_length=$(bc -l <<< "scale = 0; $bar_length * $progress / 1")
		local empty_length=$((bar_length - filled_length))

		local bar_filled=$(progress_bar_part "$PROGRESS_BAR_FILLED" "$filled_length" "$PROGRESS_BAR_FILLED_PREFIX" "$PROGRESS_BAR_FILLED_SUFFIX")
		local bar_empty=$(progress_bar_part "$PROGRESS_BAR_EMPTY" "$empty_length")

		echo -n "$prefix$bar_filled$bar_empty$suffix"

		# Restore cursor position
		tput rc
	}

	progress_bar_clear()
	{
		# Save cursor position
		tput sc

		# Go to the progress-bar region
		tput cup "$((PROGRESS_SCROLL_LINES + 1))" 0

		# Clear progress-bar
		tput ed

		# Restore cursor position
		tput rc	
	}

	progress_init() # step_count
	{
		PROGRESS_TOTAL="$1"
		PROGRESS_CURR=0

		local progress_max="$PROGRESS_TOTAL/$PROGRESS_TOTAL"

		PROGRESS_BAR_ACCENT="${PROGRESS_BAR_ACCENT:-7}"

		PROGRESS_BAR_FILLED="${PROGRESS_BAR_FILLED:-#}"
		PROGRESS_BAR_EMPTY="${PROGRESS_BAR_EMPTY:- }"

		PROGRESS_BAR_PREFIX_FW="${PROGRESS_BAR_PREFIX_FW:--16}"
		PROGRESS_BAR_SUFFIX_FW="${PROGRESS_BAR_SUFFIX_FW:-${#progress_max}}"

		PROGRESS_BAR_LINES=2

		PROGRESS_BAR_FILLED_SUFFIX=$(tput sgr0)
		PROGRESS_BAR_FILLED_PREFIX=$(tput setaf "$PROGRESS_BAR_ACCENT")

		progress_init_scroll
	}

	progress_destroy()
	{
		progress_destroy_scroll

		unset PROGRESS_TOTAL PROGRESS_CURR
		unset PROGRESS_LINES PROGRESS_SCROLL_LINES
	}

	progress() # [step_name]
	{
		local step_name="${1:-}"

		[ "$(tput lines)" -ne "$PROGRESS_LINES" ] && progress_init_scroll

		progress_bar "$step_name"

		[ "$PROGRESS_CURR" -lt "$PROGRESS_TOTAL" ] && ((PROGRESS_CURR += 1))
	}
else
	progress_init() # step_count
	{
		PROGRESS_TOTAL="$1"
		PROGRESS_CURR=0
	}

	progress_destroy()
	{ 
		unset PROGRESS_TOTAL
		unset PROGRESS_CURR
	}

	progress() # [step_name] 
	{
		echo -n "$PROGRESS_CURR/$PROGRESS_TOTAL"
		[ -z "${1:-}" ] && echo || echo ": $1"

		[ "$PROGRESS_CURR" -lt "$PROGRESS_TOTAL" ] && ((PROGRESS_CURR += 1))
	}
fi
