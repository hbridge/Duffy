# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0024_user_disable_tips'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='tip_frequency_days',
            field=models.IntegerField(default=3),
            preserve_default=True,
        ),
    ]
