# Serve the HTML Report with Nginx

You can use Nginx to serve the HTML report (index.html) either locally for quick access or online for remote monitoring.

## Serve Localy with Nginx

1. Install Start and Enable Nginx :
```bash
   sudo apt update
   sudo apt install nginx
   sudo systemctl start nginx
   sudo systemctl enable nginx
```
2. Create and configure conf file of your site :
```bash
   sudo touch /etc/nginx/sites-available/chrony-network-stats
```
```bash
   sudo nano /etc/nginx/sites-available/chrony-network-stats
```
```bash
server {
    listen 127.0.0.1:80;

    alias /var/www/html/chrony-network-stats;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```
3. Enable the site and reload nginx :
```bash
sudo ln -s /etc/nginx/sites-available/chrony-network-stats /etc/nginx/sites-enabled/chrony-network-stats
sudo nginx -t 
sudo systemctl reload nginx
```
4. Access to your website : 
Go to `http://127.0.0.1` or `http://localhost` in your web browser.