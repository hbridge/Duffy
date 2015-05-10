# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0023_auto_20150508_2205'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='disable_tips',
            field=models.BooleanField(default=False),
            preserve_default=True,
        ),
    ]
