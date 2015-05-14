# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0025_user_tip_frequency_days'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='next_state',
            field=models.CharField(max_length=100, null=True),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='user',
            name='next_state_data',
            field=models.TextField(null=True),
            preserve_default=True,
        ),
    ]
