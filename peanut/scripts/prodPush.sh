#!/bin/bash

ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "cd Duffy/peanut; git fetch; git rebase origin/master"
ssh -i ~derek/derek-key-pair-east.pem ubuntu@prod.strand.duffyapp.com "sudo apachectl -k restart"

python /home/derek/prod/Duffy/peanut/tests/black_box_api_tests.py prod.strand.duffyapp.com 12