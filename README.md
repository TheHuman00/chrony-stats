# Chrony & Network Stats

A lightweight Bash script that monitors **Chrony** and **network traffic**, generates visual graphs, and produces an HTML report ideal for low-resource servers.

**[Live demo here!](https://thehuman00.github.io/demo-chrony-stats.github.io/)**

---

## Features

| Feature | Description |
|---|---|
| Lightweight | Minimal system resources required |
| Chrony monitoring | Tracks offset, stratum, RMS, frequency, and more |
| Network monitoring | Traffic stats via vnStat |
| Multi-period views | Day, week, and month graphs for Chrony stats |
| HTML report | Visual graphs + raw `chronyc` output in one page |

---

## Prerequisites

Choose one option :

### 1. Full monitoring (Chrony + Network):
```bash
sudo apt update && sudo apt install vnstat vnstati rrdtool chrony
```

Configure vnStat to monitor your network interface:
```bash
vnstat --iflist          # find your interface name
sudo vnstat -i eth0      # replace eth0 with your interface
```
**If not eth0** : ⚠️ Change your network interface in the [Configuration](#configuration) section.

### 2. Chrony only 
```bash
sudo apt update && sudo apt install rrdtool chrony
```
Set `ENABLE_NETWORK_STATS="no"` in config


---

## Installation

```bash
curl -O https://raw.githubusercontent.com/TheHuman00/chrony-stats/master/chrony-network-stats.sh
sudo chmod +x ./chrony-network-stats.sh
```

Then schedule it to run every 5 minutes open the root crontab:
```bash
sudo crontab -e
```

Add this line:
```
*/5 * * * * /path/to/chrony-network-stats.sh
```

---

## Configuration

Open the script to edit its settings : `nano chrony-network-stats.sh`

The configuration block is at the top of the file:

```bash
####################### Configuration ######################

ENABLE_NETWORK_STATS="yes"

# Replace with your actual interface (e.g., ens33, enp0s3, wlan0)
INTERFACE="eth0" ## CHANGE HERE ⚠️

PAGE_TITLE="Network Traffic and Chrony Statistics for ${INTERFACE}"
OUTPUT_DIR="/var/www/html/chrony-network-stats"
HTML_FILENAME="index.html"

RRD_DIR="/var/lib/chrony-rrd"
RRD_FILE="$RRD_DIR/chrony.rrd"

ENABLE_LOGGING="no"
LOG_FILE="/var/log/chrony-network-stats.log"

# Auto-refresh in seconds (0 = disabled)
AUTO_REFRESH_SECONDS=0

# Show a link to this GitHub repo in the HTML page (optional, disabled by default)
GITHUB_REPO_LINK_SHOW="no"

###### Advanced Configuration ######

# DNS reverse lookups for chronyc: "no" is faster and reduces network traffic
CHRONY_ALLOW_DNS_LOOKUP="no"

# Screen preset: default | 2k | 4k
# Adjusts container width, font size, and graph resolution
DISPLAY_PRESET="default"

TIMEOUT_SECONDS=5

# Filters abnormally high values caused by Chrony restarts (e.g. spikes of 12M packets)
# Values above this threshold are replaced with gaps in the graph
SERVER_STATS_UPPER_LIMIT=100000

##############################################################
WIDTH=800
HEIGHT=300
##############################################################
```

### Display presets

Set `DISPLAY_PRESET` to `2k` or `4k` if the page looks too small on high-resolution screens. Each preset increases the container width, base font size, and graph resolution accordingly.

---

## Usage

**Run the script:**
```bash
sudo ./chrony-network-stats.sh
```

**View the report:**

The HTML file is generated at `/var/www/html/chrony-network-stats/index.html`. Serve it with a web server such as Apache or Nginx. → [Nginx local setup guide](nginx.md)

**Check logs** (requires `ENABLE_LOGGING="yes"` in config):
```bash
tail -f /var/log/chrony-network-stats.log
```

---

## License

Free to use however you want without restriction. See [LICENSE](LICENSE) for details.

## Built with

- [vnStat](https://humdi.net/vnstat/) — network traffic monitor
- [RRDtool](https://rrdtool.org/rrdtool/index.en.html) — data storage and graph generation
- [Chrony](https://chrony-project.org/) — NTP implementation
