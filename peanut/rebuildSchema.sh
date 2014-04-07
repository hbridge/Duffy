#!/bin/bash

python manage.py build_solr_schema | sed 5d > ~/apache-solr-3.5.0/example/solr/conf/schema.xml