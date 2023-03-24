#!/bin/sh

# variables
MY_PROJECT_DIR="myprojectdir"
MY_PROJECT_ENV_DIR="myprojectenv"
DJANGO_PROJECT_DIR="my_misago"
USER_NAME="lucifer"
SERVER_DOMAIN="nzdreamer.com www.nzdreamer.com"


mkdir ~/$MY_PROJECT_DIR
cd ~/$MY_PROJECT_DIR

# copy the whole project
cp -r $DJANGO_PROJECT_DIR/ .

# virtual env
python3 -m venv $MY_PROJECT_ENV_DIR
source $MY_PROJECT_ENV_DIR/bin/activate
pip install django gunicorn psycopg2-binary


# database ??
~/$MY_PROJECT_DIR/manage.py makemigrations
~/$MY_PROJECT_DIR/manage.py migrate
~/$MY_PROJECT_DIR/manage.py createsuperuser
~/$MY_PROJECT_DIR/manage.py collectstatic

deactivate

# guinicorn
sudo cat >> /etc/systemd/system/gunicorn.socket << EOF 
[Unit]
Description=gunicorn daemon
Requires=gunicorn.socket
After=network.target

[Service]
User=$USER_NAME
Group=www-data
WorkingDirectory=/home/$USER_NAME/$MY_PROJECT_DIR
ExecStart=/home/$USER_NAME/$MY_PROJECT_DIR/$MY_PROJECT_ENV_DIR/bin/gunicorn \ 
          --access-logfile - \
          --workers 3 \
          --bind unix:/run/gunicorn.sock \
          $DJANGO_PROJECT_DIR.wsgi:application 

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl start gunicorn.socket
sudo systemctl enable gunicorn.socket

# nginx
sudo cat >> /etc/nginx/sites-available/$DJANGO_PROJECT_DIR << EOF 
server {
    listen 80;
    server_name $SERVER_DOMAIN;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        root /home/$USER_NAME/$MY_PROJECT_DIR;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/gunicorn.sock;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/$DJANGO_PROJECT_DIR /etc/nginx/sites-enabled
sudo systemctl restart nginx
sudo ufw delete allow 8000
sudo ufw allow 'Nginx Full'