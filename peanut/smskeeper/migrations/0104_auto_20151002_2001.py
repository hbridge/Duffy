# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0103_auto_20150929_1936'),
    ]

    operations = [
        migrations.AddField(
            model_name='historicaluser',
            name='sweeping_activated',
            field=models.BooleanField(default=True),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='user',
            name='sweeping_activated',
            field=models.BooleanField(default=True),
            preserve_default=True,
        ),
    ]
