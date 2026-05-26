# Serve the HTML Report with Nginx

Use Nginx to serve the HTML report locally.

---

## 1. Install, start and enable Nginx

```bash
sudo apt update && sudo apt install nginx
sudo systemctl enable --now nginx
```

## 2. Create the site configuration

```bash
sudo nano /etc/nginx/sites-available/chrony-network-stats
```

Paste the following:

```nginx
server {
    listen 127.0.0.1:80;
    server_name localhost;

    root /var/www/html/chrony-network-stats;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

## 3. Enable the site and reload Nginx

```bash
sudo ln -s /etc/nginx/sites-available/chrony-network-stats /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## 4. Open the report

Go to `http://localhost` in your browser.

---

> **⚠️ Note on LAN exposure**
>
> The two optional sections below expose the dashboard beyond
> `127.0.0.1` and therefore expand the attack surface of the host. The
> HTML report itself discloses information about your time
> infrastructure (peers, internal IPs, software versions), and any
> web-server CVE becomes exploitable from every machine that can reach
> the listening port.
>
> On a personal LAN this is usually acceptable. **On a corporate
> network, get clearance from your security team first**, and at
> minimum keep the `allow`/`deny` block below (or an equivalent
> firewall rule) in place.

## Optional: expose the dashboard on the LAN

By default the dashboard is only reachable from the machine itself
(`127.0.0.1`). If you want to access it from other devices on your local
network, change the `listen` directive in step 2 to bind on the LAN
interface (or on all interfaces) and adjust `server_name`.

```nginx
server {
    # Listen on all interfaces, or replace 0.0.0.0 with the LAN IP
    # of this host (e.g. 192.168.1.10).
    listen 0.0.0.0:80;
    server_name _;

    # Restrict access to your local subnet. Adjust the CIDR to match
    # your network (e.g. 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12).
    allow 192.168.0.0/16;
    deny  all;

    root /var/www/html/chrony-network-stats;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

Then reload Nginx (`sudo nginx -t && sudo systemctl reload nginx`) and ...
Go to  `http://<server-lan-ip>` from another browser on the LAN.

---

## Optional: serve over HTTPS with a self-signed certificate

For a LAN-only deployment a self-signed certificate is enough. Browsers
will display a warning on the first visit; you can either accept the
exception once or import the `.crt` into your trust store.

### Generate the certificate

Replace `chrony-stats.local` and `192.168.1.10` with your hostname / IP.

```bash
sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/ssl/private/chrony-stats.key \
    -out    /etc/ssl/certs/chrony-stats.crt \
    -subj   "/CN=chrony-stats.local" \
    -addext "subjectAltName=DNS:chrony-stats.local,IP:192.168.1.10"
sudo chmod 600 /etc/ssl/private/chrony-stats.key
```

### Site configuration

Replace the config from step 2 with the following:

```nginx
# Redirect plain HTTP to HTTPS
server {
    listen 0.0.0.0:80;
    server_name _;
    return 301 https://$host$request_uri;
}

# Dashboard over HTTPS
server {
    # The 'listen ... http2' syntax works from nginx 1.9.5 up to current
    # versions. nginx >= 1.25.1 will show a deprecation warning and
    # suggests the separate 'http2 on;' directive instead.
    listen 0.0.0.0:443 ssl http2;
    server_name _;

    ssl_certificate     /etc/ssl/certs/chrony-stats.crt;
    ssl_certificate_key /etc/ssl/private/chrony-stats.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_session_cache   shared:SSL:1m;
    ssl_session_timeout 5m;

    # Restrict access to your local subnet. Adjust the CIDR to match
    # your network (e.g. 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12).
    allow 192.168.0.0/16;
    deny  all;

    root /var/www/html/chrony-network-stats;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    access_log /var/log/nginx/chrony-stats-access.log;
    error_log  /var/log/nginx/chrony-stats-error.log;
}
```

Then reload Nginx (`sudo nginx -t && sudo systemctl reload nginx`) and ...
Go to `https://<server-lan-ip>` in your browser.
