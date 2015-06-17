# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0043_auto_20150615_1925'),
    ]

    operations = [
        migrations.CreateModel(
            name='VerbData',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('base', models.CharField(max_length=40)),
                ('past', models.CharField(max_length=40, db_index=True)),
                ('past_participle', models.CharField(max_length=40, db_index=True)),
                ('s_es_ies', models.CharField(max_length=40)),
                ('ing', models.CharField(max_length=40)),
            ],
            options={
            },
            bases=(models.Model,),
        ),
    ]
