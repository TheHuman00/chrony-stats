# Chrony and network monitoring script

Bash script designed to monitor network traffic and Chrony statistics, generating visual graphs and an HTML report for easy monitoring.
It’s lightweight, requires minimal system resources, and is ideal for low-resource servers

Demo here : [https://thehuman00.github.io/demo-chrony-stats.github.io/](https://thehuman00.github.io/demo-chrony-stats.github.io/)

## Features

- **HTML report**: Creates a styled HTML page with embedded graphs and raw `chronyc` command outputs.
- **Network  monitoring**
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
   ```bash
   sudo vnstat -u -i YOUR-INTERFACE
   ```
   Replace `YOUR-INTERFACE` with your network interface. Find here :
   ```bash
   vnstat --iflist
   ```
   If not eth0 : ⚠️ Change your network interface in [Configuration](#configuration)


## Installation

1. **Download the script**:
   ```bash
   wget https://raw.githubusercontent.com/TheHuman00/chrony-stats/master/ntp-stat.sh -O /usr/local/bin/ntp-stat.sh
   ```

2. **Make the script executable**:
   ```bash
   chmod +x /usr/local/bin/ntp-stat.sh
   ```

3. **Test the script**:
   Run the script manually to ensure it works:
   ```bash
   sudo /usr/local/bin/ntp-stat.sh
   ```
   Check the output in `/var/www/ntp-stat/index.html` and/or verify logs in `/var/log/ntp-stat.log`.

## Configuration

   ```bash
   sudo nano /usr/local/bin/ntp-stat.sh
   ```

The script includes a configuration section at the top of `ntp-stat.sh`. Modify these variables as needed:

   ```bash
   [...]
   #### Configuration ####

   # ⚠️ IMPORTANT: Replace "eth0" with your actual interface 
   #    (e.g., ens33, enp0s3, wlan0, ...)
   INTERFACE="eth0"

   PAGE_TITLE="Network Traffic and NTP Statistics for ${INTERFACE}"
   OUTPUT_DIR="/var/www/ntp-stat"
   HTML_FILENAME="index.html"

   ENABLE_LOGGING="yes"
   LOG_FILE="/var/log/ntp-stat.log"
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

1. **Edit the root crontab**:
   ```bash
   sudo crontab -e
   ```

2. **Add the Following Line**:
   ```bash
   */5 * * * * /usr/local/bin/ntp-stat.sh
   ```
   This schedules the script to run every 5 minutes.

3. **Verify Crontab**:
   Check the crontab entry:
   ```bash
   sudo crontab -l
   ```

## Usage

1. **Run the Script**:
   ```bash
   sudo /usr/local/bin/ntp-stat.sh
   ```

2. **View the Output**:
   - The HTML report is generated at `/var/www/ntp-stat/index.html`.
   - Open this file in a web browser or serve it via a web server (e.g., Apache or Nginx).

   [See here how to serve via nginx in localhost](nginx.md)

3. **Monitor Logs**:
   Check `/var/log/ntp-stat.log` for execution details and errors.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgments

Built with `vnstat`, `vnstati`, `rrdtool`, and `chrony`.
- https://humdi.net/vnstat/
- https://rrdtool.org/rrdtool/index.en.html
- https://chrony-project.org/
