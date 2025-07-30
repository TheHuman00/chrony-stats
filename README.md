# Lightweight : Monitoring Chrony and Network

Bash script designed to monitor **network traffic** and **Chrony** statistics, **generating visual graphs** and an **HTML** report for easy monitoring.
It’s lightweight, requires minimal system resources, and is ideal for low-resource servers

Demo here : [https://thehuman00.github.io/demo-chrony-stats.github.io/](https://thehuman00.github.io/demo-chrony-stats.github.io/)

## Features

- **Multi-period time views**: View Chrony statistics across day, week, and month periods
- **HTML report**: HTML page with graphs and raw `chronyc` command outputs
- **Network monitoring**: withvnStat
- **Chrony statistics**
- **Data quality**: Filters aberrant values during Chrony restarts
- **Lightweight**
- **Optional GitHub attribution**: It's completely optional by default - feel free to use it however you want, no credit needed! 👍

## Prerequisites

**Install dependencies** (on Debian/Ubuntu-based systems):

### **For full functionality (Chrony + Network stats):**
   ```bash
   sudo apt update
   sudo apt install vnstat vnstati rrdtool chrony
   ```

**Configure vnStat**
   Ensure `vnstat` is monitoring the correct network interface (e.g., `eth0`):
   Find your interface here :
   ```bash
   vnstat --iflist
   ```
   Replace `YOUR-INTERFACE` with your network interface.
   ```bash
   sudo vnstat -i YOUR-INTERFACE
   ``` 
   **If not eth0** : ⚠️ Change your network interface in [Configuration](#configuration) section !!

### **For Chrony-only monitoring (set `ENABLE_NETWORK_STATS="no"`):**
   ```bash
   sudo apt update
   sudo apt install rrdtool chrony
   ```

## Installation

1. **Download the script**:
   ```bash
   wget https://raw.githubusercontent.com/TheHuman00/chrony-stats/master/chrony-network-stats.sh -O $HOME/chrony-network-stats.sh
   ```

2. **Make the script executable**:
   ```bash
   sudo chmod +x $HOME/chrony-network-stats.sh
   ```

## Configuration

   ```bash
   sudo nano $HOME/chrony-network-stats.sh
   ```

The script includes a configuration section at the top of `chrony-network-stats.sh`. Modify these variables as needed:

   ```bash
   [...]
   ####################### Configuration ######################

   # Enable or disable network statistics generation using vnStat
   ENABLE_NETWORK_STATS="yes"
   
   # ⚠️ IMPORTANT: Replace "eth0" with your actual interface 
   #    (e.g., ens33, enp0s3, wlan0, ...)
   INTERFACE="eth0"

   PAGE_TITLE="Network Traffic and Chrony Statistics for ${INTERFACE}"
   OUTPUT_DIR="/var/www/html/chrony-network-stats"
   HTML_FILENAME="index.html"

   RRD_DIR="/var/lib/chrony-rrd"
   RRD_FILE="$RRD_DIR/chrony.rrd"

   ENABLE_LOGGING="yes"
   LOG_FILE="/var/log/chrony-network-stats.log"

   # Auto-refresh interval in seconds (0 = disabled, e.g., 300 for 5 minutes)
   AUTO_REFRESH_SECONDS=0

   ## You can display or not the link to the chrony-stats GitHub repository in the HTML page
   ## It's completely optional by default - feel free to use it however you want, no credit needed! 👍
   GITHUB_REPO_LINK_SHOW="no"

   ###### Advanced Configuration ######

   TIMEOUT_SECONDS=5
   WIDTH=800
   HEIGHT=300

   ## When chrony restarts, it can generate abnormally high statistical values (e.g., 12M packets)
   ## that distort the graph scale. This parameter filters out values above the threshold,
   ## creating gaps in the graph instead of displaying misleading spikes.
   SERVER_STATS_UPPER_LIMIT=100000
   ##############################################################
   [...]
   ```
   Close with Ctrl+X --> Y --> Enter


## Usage

1. **Run the Script**:
   ```bash
   sudo $HOME/chrony-network-stats.sh
   ```

2. **View the Output**:
   - The HTML report is generated at `/var/www/chrony-network-stats/index.html`
   - Serves this file via a web server (e.g., Apache or Nginx)

   [See here how to serve via nginx in localhost](nginx.md)

3. **Monitor Logs**:
   Check `/var/log/chrony-network-stats.log` for execution details and errors.

## Setting up a crontab (Run every 5 minutes)

To run the script every 5 minutes with `sudo` privileges, configure the root crontab :

1. **Add in the root crontab**:
   ```bash
   ( sudo crontab -l 2>/dev/null; echo "*/5 * * * * $HOME/chrony-network-stats.sh" ) | sudo crontab -
   ```
   This adds the script to the root crontab and schedules it to run every 5 minutes.

2. **Verify Crontab**:
   Check the crontab entry:
   ```bash
   sudo crontab -l
   ```


## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

Built with `vnstat`, `vnstati`, `rrdtool`, and `chrony`.
- https://humdi.net/vnstat/
- https://rrdtool.org/rrdtool/index.en.html
- https://chrony-project.org/
