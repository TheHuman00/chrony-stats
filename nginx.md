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
