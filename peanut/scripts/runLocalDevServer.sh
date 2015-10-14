#/bin/bash
# run from peanut directory

rabbitmq-server &
killall java
mvn -f ../natty/pom.xml exec:java &
./scripts/celery.sh stop local
./scripts/celery.sh start local
launchctl unload scripts/LaunchAgents/com.duffyapp.osx.smrt_server.plist
launchctl load scripts/LaunchAgents/com.duffyapp.osx.smrt_server.plist
rm /tmp/mysql.sock
ln -s /Applications/MAMP/tmp/mysql/mysql.sock /tmp/mysql.sock
./manage.py runserver 0.0.0.0:7500

# after ctrl-c this will execute
echo "\nCleaning up..."
launchctl unload scripts/LaunchAgents/com.duffyapp.osx.smrt_server.plist
