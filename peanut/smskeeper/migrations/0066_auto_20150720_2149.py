# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0065_auto_20150720_1818'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='digest_hour',
            field=models.IntegerField(default=9),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='user',
            name='digest_minute',
            field=models.IntegerField(default=9),
            preserve_default=True,
        ),
    ]
