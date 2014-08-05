#!/bin/bash

ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "cd Duffy/peanut; git fetch; git rebase origin/master"
ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "sudo apachectl -k restart"

python /home/derek/prod/Duffy/peanut/tests/black_box_api_tests.py prod.strand.duffyapp.com 12

echo "Restarting scripts..."
ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "sudo restart duffy-strand-notifications"
ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "sudo restart duffy-friends"
ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "sudo restart duffy-stranding" 

