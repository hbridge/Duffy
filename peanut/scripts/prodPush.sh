#!/bin/bash

ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "cd Duffy/peanut; git fetch; git rebase origin/master"
ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "sudo apachectl -k restart"

# Doesn't work due to environment issues, do manually for now
#ssh -i ~derek/derek-key-pair-east.pem ubuntu@db.prod.strand.duffyapp.com "source ~/.bashrc; cd Duffy/peanut; python manage.py syncdb" 

export DJANGO_SETTINGS_MODULE=peanut.settings.prod
python /home/ubuntu/dev/Duffy/peanut/tests/black_box_api_tests.py prod.strand.duffyapp.com 5020
export DJANGO_SETTINGS_MODULE=peanut.settings.dev

echo "Restarting scripts..."
ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "sudo restart duffy-strand-notifications"
ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "sudo stop duffy-celery"
ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "sudo start duffy-celery" 
ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "sudo restart duffy-celery-beat" 

