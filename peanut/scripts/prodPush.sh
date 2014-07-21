#!/bin/bash

ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "cd Duffy/peanut; git fetch; git rebase origin/master"
ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "sudo apachectl -k restart"

python /home/derek/prod/Duffy/peanut/tests/black_box_api_tests.py prod.strand.duffyapp.com 12

read -p "Restart scripts? (y/n) " RESP
if [ "$RESP" = "y" ]; then
  ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "sudo restart duffy-strand-notifications"
  ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "sudo restart duffy-neighbor" 
else
  echo "Not restarting scripts"
fi

