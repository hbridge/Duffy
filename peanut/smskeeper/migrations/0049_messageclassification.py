# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0048_auto_20150630_1831'),
    ]

    operations = [
        migrations.CreateModel(
            name='MessageClassification',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('messageText', models.TextField(null=True)),
                ('classification', models.CharField(db_index=True, max_length=100, blank=True)),
                ('added', models.DateTimeField(db_index=True, auto_now_add=True, null=True)),
                ('updated', models.DateTimeField(db_index=True, auto_now=True, null=True)),
                ('message', models.ForeignKey(to='smskeeper.Message')),
            ],
            options={
            },
            bases=(models.Model,),
        ),
    ]
