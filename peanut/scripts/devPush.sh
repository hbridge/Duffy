#!/bin/bash

cd /home/ubuntu/Duffy
git fetch
git rebase origin/master
sudo apachectl -k restart

echo "Restarting scripts..."
sudo stop duffy-strand-notifications
sudo start duffy-strand-notifications
sudo stop duffy-friends
sudo start duffy-friends
sudo stop duffy-stranding
sudo start duffy-stranding

python /home/ubuntu/Duffy/peanut/tests/black_box_api_tests.py dev.duffyapp.com 297

initctl list | grep duffy-strand-notifications
initctl list | grep duffy-friends
initctl list | grep duffy-stranding