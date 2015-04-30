# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0011_auto_20150430_0017'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='activated',
            field=models.BooleanField(default=False),
            preserve_default=True,
        ),
    ]
