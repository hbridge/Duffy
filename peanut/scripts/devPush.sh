#!/bin/bash

cd /home/derek/prod/Duffy
git fetch
git rebase origin/master
sudo apachectl -k restart

python /home/derek/prod/Duffy/peanut/tests/black_box_api_tests.py dev.duffyapp.com 297

echo "Restarting scripts..."
sudo stop duffy-strand-notifications
sudo start duffy-strand-notifications
sudo stop duffy-neighbor
sudo start duffy-neighbor
sudo stop duffy-friends
sudo start duffy-friends
sudo stop duffy-stranding
sudo start duffy-stranding
