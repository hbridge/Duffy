#!/bin/bash

cd /home/derek/prod/Duffy
git fetch
git rebase origin/master
sudo apachectl -k restart

python /home/derek/prod/Duffy/peanut/tests/black_box_api_tests.py dev.duffyapp.com 297

echo "Restarting scripts..."
sudo restart duffy-strand-notifications
sudo restart duffy-neighbor
