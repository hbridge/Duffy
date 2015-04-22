# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('memfresh', '0005_auto_20150421_2333'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='followup',
            name='is_next',
        ),
        migrations.AddField(
            model_name='followup',
            name='from_event_id',
            field=models.CharField(default='', max_length=1000),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name='followup',
            name='sent_back',
            field=models.BooleanField(default=False),
            preserve_default=True,
        ),
        migrations.AlterField(
            model_name='followup',
            name='text',
            field=models.CharField(max_length=1000, null=True),
        ),
    ]
