# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0067_auto_20150720_2158'),
    ]

    operations = [
        migrations.AddField(
            model_name='message',
            name='classification_scores_json',
            field=models.CharField(max_length=1000, null=True, blank=True),
            preserve_default=True,
        ),
    ]
