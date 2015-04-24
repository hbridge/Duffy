# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0003_auto_20150423_1810'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='completed_tutorial',
            field=models.BooleanField(default=False),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='user',
            name='tutorial_step',
            field=models.IntegerField(default=0),
            preserve_default=True,
        ),
    ]
