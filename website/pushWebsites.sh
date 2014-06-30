#!/bin/bash

s3cmd --config=/home/derek/.s3cfg sync www/ s3://www.duffyapp.com/
