# Lightweight : Monitoring Chrony and Network

Bash script designed to monitor **network traffic** and **Chrony** statistics, **generating visual graphs** and an **HTML** report for easy monitoring.
It’s lightweight, requires minimal system resources, and is ideal for low-resource servers

Demo here : [https://thehuman00.github.io/demo-chrony-stats.github.io/](https://thehuman00.github.io/demo-chrony-stats.github.io/)

## Features

- **HTML report**: Creates a styled HTML page with embedded graphs and raw `chronyc` command outputs.
- **Network  monitoring** : vnStat
- **Chrony statistics**
- **Lightweight**: Designed to be resource-efficient, with minimal overhead and no heavy dependencies.

## Requirements

- **Dependencies**:
  - `vnstat` + `vnstati` : For network traffic monitoring + graph generation.
  - `chrony` : For NTP statistics collection.
  - `rrdtool` : For creating and managing the Round-Robin Database.
  - `timeout` (part of `coreutils`) : For setting timeouts on `chronyc` commands.

**Install dependencies** (on Debian/Ubuntu-based systems):
   ```bash
   sudo apt update
   sudo apt install vnstat vnstati rrdtool chrony coreutils
   ```
**Configure vnStat**:
   Ensure `vnstat` is monitoring the correct network interface (e.g., `eth0`):
   Find your interface here :
   ```bash
   vnstat --iflist
   ```
   Replace `YOUR-INTERFACE` with your network interface.
   ```bash
   sudo vnstat -u -i YOUR-INTERFACE
   ``` 
   If not eth0 : ⚠️ Change your network interface in [Configuration](#configuration)


## Installation

1. **Download the script**:
   ```bash
   wget https://raw.githubusercontent.com/TheHuman00/chrony-stats/master/chrony-network-stats.sh -O $HOME/chrony-network-stats.sh
   ```

2. **Make the script executable**:
   ```bash
   sudo chmod +x $HOME/chrony-network-stats.sh
   ```

3. **Test the script**:
   Run the script manually to ensure it works:
   ```bash
   sudo $HOME/chrony-network-stats.sh
   ```
   Check the output in `/var/www/chrony-network-stats/index.html` and/or verify logs in `/var/log/chrony-network-stats.log`.

## Configuration

   ```bash
   sudo nano $HOME/chrony-network-stats.sh
   ```

The script includes a configuration section at the top of `chrony-network-stats.sh`. Modify these variables as needed:

   ```bash
   [...]
   #### Configuration ####

   # ⚠️ IMPORTANT: Replace "eth0" with your actual interface 
   #    (e.g., ens33, enp0s3, wlan0, ...)
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
   #########################
   [...]
   ```


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

## Usage

1. **Run the Script**:
   ```bash
   sudo $HOME/chrony-network-stats.sh
   ```

2. **View the Output**:
   - The HTML report is generated at `/var/www/chrony-network-stats/index.html`.
   - Open this file in a web browser or serve it via a web server (e.g., Apache or Nginx).

   [See here how to serve via nginx in localhost](nginx.md)

3. **Monitor Logs**:
   Check `/var/log/chrony-network-stats.log` for execution details and errors.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

Built with `vnstat`, `vnstati`, `rrdtool`, and `chrony`.
- https://humdi.net/vnstat/
- https://rrdtool.org/rrdtool/index.en.html
- https://chrony-project.org/
