#!/bin/bash

s3cmd --config=/home/ubuntu/dev/Duffy/website/.s3cfg --delete-removed sync www/ s3://www.duffyapp.com/
