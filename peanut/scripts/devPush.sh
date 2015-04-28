#!/bin/bash
sudo su ubuntu <<'EOF'
cd /home/ubuntu/dev/Duffy
git fetch
git rebase origin/master
sudo apachectl -k restart
EOF

echo "Restarting scripts..."
sudo stop duffy-strand-notifications
sudo start duffy-strand-notifications
sudo stop duffy-celery
sudo start duffy-celery
sudo stop duffy-celery-beat
sudo start duffy-celery-beat

#source /home/ubuntu/env/bin/activate; python /home/ubuntu/dev/Duffy/peanut/tests/black_box_api_tests.py dev.duffyapp.com 653

initctl list | grep duffy-strand-notifications
initctl list | grep duffy-celery
initctl list | grep duffy-celery-beat
