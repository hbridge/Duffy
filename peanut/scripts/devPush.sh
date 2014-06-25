#!/bin/bash

cd /home/derek/prod/Duffy
git fetch
git rebase origin/master
sudo apachectl -k restart