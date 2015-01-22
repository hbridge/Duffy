#!/bin/bash
sudo su ubuntu <<'EOF'
cd /home/ubuntu/dev/Duffy
git fetch
git rebase origin/master
sudo apachectl -k restart
EOF

echo "Restarting scripts..."
sudo stop duffy-friends
sudo start duffy-friends
sudo stop duffy-stranding
sudo start duffy-stranding
sudo stop duffy-neighboring
sudo start duffy-neighboring
sudo stop duffy-popcaches
sudo start duffy-popcaches
sudo stop duffy-strand-notifications
sudo start duffy-strand-notifications
sudo stop duffy-suggestion-notifications
sudo start duffy-suggestion-notifications
sudo stop duffy-celery
sudo start duffy-celery

source /home/ubuntu/env/bin/activate; python /home/ubuntu/dev/Duffy/peanut/tests/black_box_api_tests.py dev.duffyapp.com 653

initctl list | grep duffy-strand-notifications
initctl list | grep duffy-friends
initctl list | grep duffy-stranding
initctl list | grep duffy-neighboring
initctl list | grep duffy-popcaches
initctl list | grep duffy-suggestion-notifications
initctl list | grep duffy-celery
