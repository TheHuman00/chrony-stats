#!/bin/bash
set -e

#### Configuration ####
INTERFACE="eth0"

PAGE_TITLE="Network Traffic and Chrony Statistics for ${INTERFACE}"
OUTPUT_DIR="/var/www/chrony-network-stats"
HTML_FILENAME="index.html"

ENABLE_LOGGING="yes"
LOG_FILE="/var/log/chrony-network-stats.log"
RRD_DIR="/var/lib/chrony-rrd"
RRD_FILE="$RRD_DIR/chrony.rrd"
WIDTH=800
HEIGHT=300
TIMEOUT_SECONDS=5
#######################

log_message() {
    local level="$1"
    local message="$2"
    if [[ "$ENABLE_LOGGING" == "yes" ]]; then
    	echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
    fi
    	echo "[$level] $message"
}

validate_numeric() {
    local value="$1"
    local name="$2"
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "Invalid $name: $value. Must be numeric."
        exit 1
    fi
}

check_commands() {
    local commands=("vnstati" "rrdtool" "chronyc" "sudo" "timeout")
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log_message "ERROR" "Command '$cmd' not found in PATH."
            exit 1
        fi
    done
}

setup_directories() {
    log_message "INFO" "Checking and preparing directories..."
    for dir in "$OUTPUT_DIR" "$RRD_DIR"; do
        mkdir -p "$dir" || {
            log_message "ERROR" "Failed to create directory: $dir"
            exit 1
        }
        if [ ! -w "$dir" ]; then
            log_message "ERROR" "Directory '$dir' is not writable."
            exit 1
        fi
    done
}

generate_vnstat_images() {
    log_message "INFO" "Generating vnStat images for interface '$INTERFACE'..."
    local modes=("s" "d" "t" "h" "m" "y")
    for mode in "${modes[@]}"; do
        vnstati -"$mode" -i "$INTERFACE" -o "$OUTPUT_DIR/vnstat_${mode}.png" || {
            log_message "ERROR" "Failed to generate vnstat image for mode $mode"
            exit 1
        }
    done
}

collect_chrony_data() {
    log_message "INFO" "Collecting Chrony data..."
    get_html() {
        timeout "$TIMEOUT_SECONDS"s sudo chronyc "$1" -v 2>&1 | sed 's/&/\&/g;s/</\</g;s/>/\>/g;s/$/<br>/' || {
            log_message "ERROR" "Failed to collect chronyc $1 data"
            return 1
        }
    }

    RAW_TRACKING=$(timeout "$TIMEOUT_SECONDS"s sudo chronyc tracking) || {
        log_message "ERROR" "Failed to collect chronyc tracking data"
        exit 1
    }
    CHRONYC_TRACKING_HTML=$(echo "$RAW_TRACKING" | sed 's/&/\&/g;s/</\</g;s/>/\>/g;s/$/<br>/')
    CHRONYC_SOURCES=$(get_html sources) || exit 1
    CHRONYC_SOURCESTATS=$(get_html sourcestats) || exit 1
    CHRONYC_SELECTDATA=$(get_html selectdata) || exit 1
}

extract_chronyc_values() {
    extract_val() {
        echo "$RAW_TRACKING" | awk "/$1/ {print \$($2)}" | grep -E '^[-+]?[0-9.]+$' || echo "U"
    }

    OFFSET=$(extract_val "Last offset" "NF-1")

    local systime_line
    systime_line=$(echo "$RAW_TRACKING" | grep "System time")
    if [[ -n "$systime_line" ]]; then
        local value
        value=$(echo "$systime_line" | awk '{print $4}')
        if [[ "$systime_line" == *"slow"* ]]; then
            SYSTIME="-$value"
        else
            SYSTIME="$value"
        fi
    else
        SYSTIME="U"
    fi

    FREQ=$(extract_val "Frequency" "NF-2")
    RESID_FREQ=$(extract_val "Residual freq" "NF-1")
    SKEW=$(extract_val "Skew" "NF-1")
    DELAY=$(extract_val "Root delay" "NF-1")
    DISPERSION=$(extract_val "Root dispersion" "NF-1")
    STRATUM=$(extract_val "Stratum" "3")

    RAW_STATS=$(LC_ALL=C sudo chronyc serverstats) || {
        log_message "ERROR" "Failed to collect chronyc serverstats"
        exit 1
    }
    get_stat() {
        echo "$RAW_STATS" | awk -F'[[:space:]]*:[[:space:]]*' "/$1/ {print \$2}" | grep -E '^[0-9]+$' || echo "U"
    }
    PKTS_RECV=$(get_stat "NTP packets received")
    PKTS_DROP=$(get_stat "NTP packets dropped")
    CMD_RECV=$(get_stat "Command packets received")
    CMD_DROP=$(get_stat "Command packets dropped")
    LOG_DROP=$(get_stat "Client log records dropped")
    NTS_KE_ACC=$(get_stat "NTS-KE connections accepted")
    NTS_KE_DROP=$(get_stat "NTS-KE connections dropped")
    AUTH_PKTS=$(get_stat "Authenticated NTP packets")
    INTERLEAVED=$(get_stat "Interleaved NTP packets")
    TS_HELD=$(get_stat "NTP timestamps held")
}

create_rrd_database() {
    if [ ! -f "$RRD_FILE" ]; then
        log_message "INFO" "Creating new RRD file: $RRD_FILE"
        LC_ALL=C rrdtool create "$RRD_FILE" --step 300 \
            DS:offset:GAUGE:600:U:U DS:frequency:GAUGE:600:U:U DS:resid_freq:GAUGE:600:U:U DS:skew:GAUGE:600:U:U \
            DS:delay:GAUGE:600:U:U DS:dispersion:GAUGE:600:U:U DS:stratum:GAUGE:600:0:16 \
	    DS:systime:GAUGE:600:U:U \
            DS:pkts_recv:COUNTER:600:0:U DS:pkts_drop:COUNTER:600:0:U DS:cmd_recv:COUNTER:600:0:U \
            DS:cmd_drop:COUNTER:600:0:U DS:log_drop:COUNTER:600:0:U DS:nts_ke_acc:COUNTER:600:0:U \
            DS:nts_ke_drop:COUNTER:600:0:U DS:auth_pkts:COUNTER:600:0:U DS:interleaved:COUNTER:600:0:U \
            DS:ts_held:GAUGE:600:0:U \
            RRA:AVERAGE:0.5:1:576 RRA:AVERAGE:0.5:6:672 RRA:AVERAGE:0.5:24:732 RRA:AVERAGE:0.5:288:730 \
            RRA:MAX:0.5:1:576 RRA:MAX:0.5:6:672 RRA:MAX:0.5:24:732 RRA:MAX:0.5:288:730 \
            RRA:MIN:0.5:1:576 RRA:MIN:0.5:6:672 RRA:MIN:0.5:24:732 RRA:MIN:0.5:288:730 || {
                log_message "ERROR" "Failed to create RRD database"
                exit 1
            }
    fi
}

update_rrd_database() {
    log_message "INFO" "Updating RRD database..."
    UPDATE_STRING="N:$OFFSET:$FREQ:$RESID_FREQ:$SKEW:$DELAY:$DISPERSION:$STRATUM:$SYSTIME:$PKTS_RECV:$PKTS_DROP:$CMD_RECV:$CMD_DROP:$LOG_DROP:$NTS_KE_ACC:$NTS_KE_DROP:$AUTH_PKTS:$INTERLEAVED:$TS_HELD"
    LC_ALL=C rrdtool update "$RRD_FILE" "$UPDATE_STRING" || {
        log_message "ERROR" "Failed to update RRD database"
        exit 1
    }
}

generate_graphs() {
    log_message "INFO" "Generating graphs..."
    local END_TIME=$(date +%s)
    local START_TIME=$((END_TIME - 86400))
    declare -A graphs=(
        ["chrony_serverstats"]="--title 'Chrony Server Statistics - by day' --vertical-label 'Packets/second' \
            --lower-limit 0 --units-exponent 0 \
            DEF:pkts_recv='$RRD_FILE':pkts_recv:AVERAGE \
            DEF:pkts_drop='$RRD_FILE':pkts_drop:AVERAGE \
            DEF:cmd_recv='$RRD_FILE':cmd_recv:AVERAGE \
            DEF:cmd_drop='$RRD_FILE':cmd_drop:AVERAGE \
            DEF:log_drop='$RRD_FILE':log_drop:AVERAGE \
            DEF:nts_ke_acc='$RRD_FILE':nts_ke_acc:AVERAGE \
            DEF:nts_ke_drop='$RRD_FILE':nts_ke_drop:AVERAGE \
            DEF:auth_pkts='$RRD_FILE':auth_pkts:AVERAGE \
            'COMMENT: \l' \
            'AREA:pkts_recv#C4FFC4:Packets received            ' \
            'LINE1:pkts_recv#00E000:' \
            'GPRINT:pkts_recv:LAST:Cur\: %5.2lf%s' \
            'GPRINT:pkts_recv:MIN:Min\: %5.2lf%s' \
            'GPRINT:pkts_recv:AVERAGE:Avg\: %5.2lf%s' \
            'GPRINT:pkts_recv:MAX:Max\: %5.2lf%s\l' \
            'LINE1:pkts_drop#FF8C00:Packets dropped             ' \
            'GPRINT:pkts_drop:LAST:Cur\: %5.2lf%s' \
            'GPRINT:pkts_drop:MIN:Min\: %5.2lf%s' \
            'GPRINT:pkts_drop:AVERAGE:Avg\: %5.2lf%s' \
            'GPRINT:pkts_drop:MAX:Max\: %5.2lf%s\l' \
            'LINE1:cmd_recv#4169E1:Command packets received    ' \
            'GPRINT:cmd_recv:LAST:Cur\: %5.2lf%s' \
            'GPRINT:cmd_recv:MIN:Min\: %5.2lf%s' \
            'GPRINT:cmd_recv:AVERAGE:Avg\: %5.2lf%s' \
            'GPRINT:cmd_recv:MAX:Max\: %5.2lf%s\l' \
            'LINE1:cmd_drop#FFD700:Command packets dropped     ' \
            'GPRINT:cmd_drop:LAST:Cur\: %5.2lf%s' \
            'GPRINT:cmd_drop:MIN:Min\: %5.2lf%s' \
            'GPRINT:cmd_drop:AVERAGE:Avg\: %5.2lf%s' \
            'GPRINT:cmd_drop:MAX:Max\: %5.2lf%s\l' \
            'LINE1:log_drop#9400D3:Client log records dropped  ' \
            'GPRINT:log_drop:LAST:Cur\: %5.2lf%s' \
            'GPRINT:log_drop:MIN:Min\: %5.2lf%s' \
            'GPRINT:log_drop:AVERAGE:Avg\: %5.2lf%s' \
            'GPRINT:log_drop:MAX:Max\: %5.2lf%s\l' \
            'LINE1:nts_ke_acc#8A2BE2:NTS-KE connections accepted ' \
            'GPRINT:nts_ke_acc:LAST:Cur\: %5.2lf%s' \
            'GPRINT:nts_ke_acc:MIN:Min\: %5.2lf%s' \
            'GPRINT:nts_ke_acc:AVERAGE:Avg\: %5.2lf%s' \
            'GPRINT:nts_ke_acc:MAX:Max\: %5.2lf%s\l' \
            'LINE1:nts_ke_drop#9370DB:NTS-KE connections dropped  ' \
            'GPRINT:nts_ke_drop:LAST:Cur\: %5.2lf%s' \
            'GPRINT:nts_ke_drop:MIN:Min\: %5.2lf%s' \
            'GPRINT:nts_ke_drop:AVERAGE:Avg\: %5.2lf%s' \
            'GPRINT:nts_ke_drop:MAX:Max\: %5.2lf%s\l' \
            'LINE1:auth_pkts#FF0000:Authenticated NTP packets   ' \
            'GPRINT:auth_pkts:LAST:Cur\: %5.2lf%s' \
            'GPRINT:auth_pkts:MIN:Min\: %5.2lf%s' \
            'GPRINT:auth_pkts:AVERAGE:Avg\: %5.2lf%s' \
            'GPRINT:auth_pkts:MAX:Max\: %5.2lf%s\l'"
        ["chrony_tracking"]="--title 'Chrony Dispersion + Stratum - by day' --vertical-label 'milliseconds' --alt-autoscale \
            --units-exponent 0 \
            DEF:stratum='$RRD_FILE':stratum:AVERAGE \
            DEF:freq='$RRD_FILE':frequency:AVERAGE \
            DEF:skew='$RRD_FILE':skew:AVERAGE \
            DEF:delay='$RRD_FILE':delay:AVERAGE \
            DEF:dispersion='$RRD_FILE':dispersion:AVERAGE \
            CDEF:skew_scaled=skew,100,* \
            CDEF:delay_scaled=delay,1000,* \
            CDEF:disp_scaled=dispersion,1000,* \
            'COMMENT: \l' \
            'LINE1:stratum#00ff00:Stratum                                    ' \
            'GPRINT:stratum:LAST:  Cur\: %5.2lf%s' \
            'GPRINT:stratum:MIN:Min\: %5.2lf%s' \
            'GPRINT:stratum:AVERAGE:Avg\: %5.2lf%s' \
            'GPRINT:stratum:MAX:Max\: %5.2lf%s\l' \
            'LINE1:disp_scaled#9400D3:Root dispersion    [Root dispersion]       ' \
            'GPRINT:disp_scaled:LAST:  Cur\: %5.2lf%s' \
            'GPRINT:disp_scaled:MIN:Min\: %5.2lf%s' \
            'GPRINT:disp_scaled:AVERAGE:Avg\: %5.2lf%s' \
            'GPRINT:disp_scaled:MAX:Max\: %5.2lf%s\l'"
        ["chrony_offset"]="--title 'Chrony System Time Offset - by day' --vertical-label 'milliseconds' \
            DEF:offset='$RRD_FILE':offset:AVERAGE \
	    DEF:systime='$RRD_FILE':systime:AVERAGE \
	    CDEF:systime_scaled=systime,1000,* \
	    CDEF:offset_ms=offset,1000,* \
            'LINE2:offset_ms#00ff00:Actual Offset from NTP Source [Last Offset] ' \
            'GPRINT:offset_ms:LAST:  Cur\: %5.2lf%s' \
	    'GPRINT:offset_ms:MIN:Min\: %5.2lf%s' \
            'GPRINT:offset_ms:AVERAGE:Avg\: %5.2lf%s' \
            'GPRINT:offset_ms:MAX:Max\: %5.2lf%s\l' \
            'LINE1:systime_scaled#4169E1:System Clock Adjustment       [System Time] ' \
            'GPRINT:systime_scaled:LAST:  Cur\: %5.2lf%s' \
            'GPRINT:systime_scaled:MIN:Min\: %5.2lf%s' \
            'GPRINT:systime_scaled:AVERAGE:Avg\: %5.2lf%s' \
            'GPRINT:systime_scaled:MAX:Max\: %5.2lf%s\l'"
        ["chrony_delay"]="--title 'Chrony Root Delay - by day' --vertical-label 'milliseconds' --units-exponent 0 \
            DEF:delay='$RRD_FILE':delay:AVERAGE \
            CDEF:delay_ms=delay,1000,* \
            LINE2:delay_ms#00ff00:'Network Delay to Root Source   [Root Delay]  ' \
            'GPRINT:delay_ms:LAST:Cur\: %5.2lf%s' \
            'GPRINT:delay_ms:MIN:Min\: %5.2lf%s' \
            'GPRINT:delay_ms:AVERAGE:Avg\: %5.2lf%s' \
            'GPRINT:delay_ms:MAX:Max\: %5.2lf%s\l'"
        ["chrony_frequency"]="--title 'Chrony Clock Frequency Error - by day' --vertical-label 'ppm'\
            DEF:freq='$RRD_FILE':frequency:AVERAGE \
            DEF:resid_freq='$RRD_FILE':resid_freq:AVERAGE \
            CDEF:resfreq_scaled=resid_freq,100,* \
            CDEF:freq_scaled=freq,1,* \
            'LINE2:freq_scaled#00ff00:Natural Clock Drift      [Frequency]         ' \
            'GPRINT:freq_scaled:LAST:Cur\: %5.2lf%s' \
            'GPRINT:freq_scaled:MIN:Min\: %5.2lf%s' \
            'GPRINT:freq_scaled:AVERAGE:Avg\: %5.2lf%s' \
            'GPRINT:freq_scaled:MAX:Max\: %5.2lf%s\n' \
            'LINE1:resfreq_scaled#4169E1:Residual Drift (x100)    [Residual freq]     ' \
            'GPRINT:resfreq_scaled:LAST:Cur\: %5.2lf%s' \
            'GPRINT:resfreq_scaled:MIN:Min\: %5.2lf%s' \
            'GPRINT:resfreq_scaled:AVERAGE:Avg\: %5.2lf%s' \
            'GPRINT:resfreq_scaled:MAX:Max\: %5.2lf%s\l'"
	["chrony_drift"]="--title 'Chrony Drift Margin Error - by day' --vertical-label 'ppm' \
            --units-exponent 0 \
            DEF:resid_freq='$RRD_FILE':resid_freq:AVERAGE \
            DEF:skew_raw='$RRD_FILE':skew:AVERAGE \
            CDEF:resfreq_scaled=resid_freq,100,* \
	    CDEF:skew_scaled=skew_raw,100,* \
            'COMMENT: \l' \
            'LINE1:skew_scaled#00ff00:Estimate Drift Error Margin (x100)  [Skew]   ' \
            'GPRINT:skew_scaled:LAST:Cur\: %5.2lf' \
            'GPRINT:skew_scaled:MIN:Min\: %5.2lf' \
            'GPRINT:skew_scaled:AVERAGE:Avg\: %5.2lf' \
            'GPRINT:skew_scaled:MAX:Max\: %5.2lf\l'"
    )

    for graph in "${!graphs[@]}"; do
        local cmd="LC_ALL=C rrdtool graph '$OUTPUT_DIR/$graph.png' --width '$WIDTH' --height '$HEIGHT' --start end-1d --end now-180s ${graphs[$graph]}"
        eval "$cmd" || {
            log_message "ERROR" "Failed to generate graph: $graph"
            exit 1
        }
    done
}

generate_html() {
    log_message "INFO" "Generating HTML report..."
    local GENERATED_TIMESTAMP=$(date)
    cat >"$OUTPUT_DIR/$HTML_FILENAME" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${PAGE_TITLE} - Server Status</title>
    <style>
        :root {
            --primary-text: #212529;
            --secondary-text: #6c757d;
            --background-color: #f8f9fa;
            --content-background: #ffffff;
            --border-color: #787879;
            --code-background: #e1e1e1;
            --code-text: #000000;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: var(--background-color);
            color: var(--primary-text);
            line-height: 1.6;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background-color: var(--content-background);
            padding: 20px 20px;
            border-radius: 8px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.05);
        }
        header {
            text-align: center;
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 20px;
            margin-bottom: 30px;
        }
        header h1 {
            margin: 0;
            font-size: 2.5em;
            color: var(--primary-text);
        }
        section {
            margin-bottom: 40px;
        }
        h2 {
            font-size: 1.8em;
            color: var(--primary-text);
            border-bottom: 1px solid var(--border-color);
            padding-bottom: 10px;
            margin-top: 0;
            margin-bottom: 20px;
        }
        h2 a {
            font-size: 0.8em;
            font-weight: normal;
            vertical-align: middle;
            margin-left: 10px;
        }
        h3 {
            font-size: 1.3em;
            color: var(--primary-text);
            margin-top: 25px;
        }
	@media (max-width: 767px) {
            #vnstat-graphs table,
            #vnstat-graphs tbody,
            #vnstat-graphs tr,
            #vnstat-graphs td {
                display: block;
                width: 100%;
            }

            #vnstat-graphs td {
                padding-left: 0;
                padding-right: 0;
                text-align: center;
            }
        }
        .graph-grid {
            display: grid;
            grid-template-columns: 1fr;
            gap: 10px;
            text-align: center;
        }
        @media (min-width: 768px) {
            .graph-grid {
                grid-template-columns: repeat(2, 1fr);
            }
        }
        figure {
            margin: 0;
            padding: 0;
        }
        img {
            max-width: 100%;
            height: auto;
            border: 1px solid var(--border-color);
            border-radius: 4px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        pre {
            background-color: var(--code-background);
            color: var(--code-text);
            padding: 10px;
            border: 1px solid #c3bebe;
            border-radius: 4px;
            overflow-x: auto;
            white-space: pre-wrap;
            word-wrap: break-word;
            font-size: 0.8em;
        }
        footer {
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid var(--border-color);
            font-size: 0.9em;
            color: var(--secondary-text);
        }
    </style>
</head>
<body>
    <div class="container">
	<main>
            <section id="chrony-graphs">
                <h2>Chrony Graphs <a target="_blank" href="https://chrony-project.org/doc/4.3/chronyc.html#:~:text=System%20clock-,tracking,-The%20tracking%20command">[Data Legend]</a></h2>
                <div class="graph-grid">
                    <figure>
                        <img src="chrony_serverstats.png" alt="Chrony server statistics graph">
                    </figure>
                    <figure>
                        <img src="chrony_offset.png" alt="Chrony system clock offset graph">
                    </figure>
                    <figure>
                        <img src="chrony_tracking.png" alt="Chrony system clock tracking graph">
                    </figure>
                    <figure>
                        <img src="chrony_delay.png" alt="Chrony sync delay graph">
                    </figure>
                    <figure>
                        <img src="chrony_frequency.png" alt="Chrony clock frequency graph">
                    </figure>
                    <figure>
                        <img src="chrony_drift.png" alt="Chrony clock frequency drift graph">
                    </figure>
                </div>
            </section>

            <section id="vnstat-graphs">
                <h2>vnStati Graphs</h2>
                <table border="0" style="margin-left: auto; margin-right: auto;">
                    <tbody>
                        <tr>
                            <td valign="top" style="padding: 0 10px;">
                                <img src="vnstat_s.png" alt="vnStat summary"><br>
                                <img src="vnstat_d.png" alt="vnStat daily" style="margin-top: 4px;"><br>
                                <img src="vnstat_t.png" alt="vnStat top 10" style="margin-top: 4px;"><br>
                            </td>
                            <td valign="top" style="padding: 0 10px;">
                                <img src="vnstat_h.png" alt="vnStat hourly"><br>
                                <img src="vnstat_m.png" alt="vnStat monthly" style="margin-top: 4px;"><br>
                                <img src="vnstat_y.png" alt="vnStat yearly" style="margin-top: 4px;"><br>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </section>

            <section id="chrony-stats">
                <h2>Chrony - NTP Statistics</h2>

                <h3>Command: <code>chronyc sources -v</code></h3>
                <pre><code>${CHRONYC_SOURCES}</code></pre>

                <h3>Command: <code>chronyc selectdata -v</code></h3>
                <pre><code>${CHRONYC_SELECTDATA}</code></pre>

                <h3>Command: <code>chronyc sourcestats -v</code></h3>
                <pre><code>${CHRONYC_SOURCESTATS}</code></pre>

                <h3>Command: <code>chronyc tracking</code></h3>
                <pre><code>${CHRONYC_TRACKING_HTML}</code></pre>
            </section>
        </main>

        <footer>
            <p>Page generated on: ${GENERATED_TIMESTAMP}</p>
        </footer>
    </div>
</body>
</html>
EOF
}

main() {
    log_message "INFO" "Starting vnstati script..."
    validate_numeric "$WIDTH" "WIDTH"
    validate_numeric "$HEIGHT" "HEIGHT"
    validate_numeric "$TIMEOUT_SECONDS" "TIMEOUT_SECONDS"
    check_commands
    setup_directories
    generate_vnstat_images
    collect_chrony_data
    extract_chronyc_values
    create_rrd_database
    update_rrd_database
    generate_graphs
    generate_html
    log_message "INFO" "HTML page and graphs generated in: $OUTPUT_DIR/$HTML_FILENAME"
    echo "✅ Successfully generated report"
}

main
