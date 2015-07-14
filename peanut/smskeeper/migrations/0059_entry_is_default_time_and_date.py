# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0058_user_last_paused_timestamp'),
    ]

    operations = [
        migrations.AddField(
            model_name='entry',
            name='is_default_time_and_date',
            field=models.BooleanField(default=False),
            preserve_default=True,
        ),
    ]
