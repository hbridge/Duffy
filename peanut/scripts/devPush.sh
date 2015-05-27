#!/bin/bash
sudo su ubuntu <<'EOF'
cd /home/ubuntu/dev/Duffy
git fetch
git rebase origin/master
cd peanut
DJANGO_SETTINGS_MODULE=peanut.settings.dev /home/ubuntu/env/bin/python manage.py test
cd static/smskeeper
jsx --extension jsx src/ build/
sudo apachectl -k restart
EOF

echo "Restarting scripts..."
sudo stop duffy-celery
sudo start duffy-celery
sudo stop duffy-celery-beat
sudo start duffy-celery-beat

#source /home/ubuntu/env/bin/activate; python /home/ubuntu/dev/Duffy/peanut/tests/black_box_api_tests.py dev.duffyapp.com 653

initctl list | grep duffy-celery
initctl list | grep duffy-celery-beat
