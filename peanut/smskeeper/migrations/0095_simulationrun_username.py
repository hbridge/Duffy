# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0094_auto_20150911_2224'),
    ]

    operations = [
        migrations.AddField(
            model_name='simulationrun',
            name='username',
            field=models.CharField(default='hbridge', max_length=10),
            preserve_default=False,
        ),
    ]
