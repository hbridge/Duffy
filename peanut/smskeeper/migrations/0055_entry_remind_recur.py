# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0054_user_last_state'),
    ]

    operations = [
        migrations.AddField(
            model_name='entry',
            name='remind_recur',
            field=models.CharField(default=b'default', max_length=100, choices=[(b'default', b'default'), (b'one-time', b'one-time'), (b'weekly', b'weekly'), (b'weekdays', b'weekdays'), (b'daily', b'daily')]),
            preserve_default=True,
        ),
    ]
