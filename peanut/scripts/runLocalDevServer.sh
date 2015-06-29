#/bin/bash
# run from peanut directory

rabbitmq-server
./scripts/celery.sh stop local
./scripts/celery.sh start local
rm /tmp/mysql.sock
ln -s /Applications/MAMP/tmp/mysql/mysql.sock /tmp/mysql.sock
./manage.py runserver 0.0.0.0:7500
