#!/bin/bash

python manage.py build_solr_schema | sed 5d > ~/apache-solr-3.5.0/example/solr/conf/schema.xml

sed -i 's/minGramSize="2"/minGramSize="1"/' ~/apache-solr-3.5.0/example/solr/conf/schema.xml

sudo restart duffy-solr