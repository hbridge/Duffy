#!/bin/bash

ssh -i ~derek/derek-key-pair-east.pem ubuntu@ec2-54-88-151-106.compute-1.amazonaws.com "cd Duffy/peanut; git fetch; git rebase origin/master"
ssh -i ~derek/derek-key-pair-east.pem ubuntu@ec2-54-88-151-106.compute-1.amazonaws.com "sudo apachectl -k restart"

python /home/derek/prod/Duffy/peanut/tests/black_box_api_tests.py prod.strand.duffyapp.com 12