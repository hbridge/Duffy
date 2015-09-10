# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0091_merge'),
    ]

    operations = [
        migrations.AlterField(
            model_name='entry',
            name='remind_recur',
            field=models.CharField(default=b'default', max_length=100, choices=[(b'default', b'default'), (b'one-time', b'one-time'), (b'weekly', b'weekly'), (b'weekdays', b'weekdays'), (b'daily', b'daily'), (b'monthly', b'monthly'), (b'every-2-days', b'every-2-days'), (b'every-2-weeks', b'every-2-weeks')]),
        ),
        migrations.AlterField(
            model_name='historicalentry',
            name='remind_recur',
            field=models.CharField(default=b'default', max_length=100, choices=[(b'default', b'default'), (b'one-time', b'one-time'), (b'weekly', b'weekly'), (b'weekdays', b'weekdays'), (b'daily', b'daily'), (b'monthly', b'monthly'), (b'every-2-days', b'every-2-days'), (b'every-2-weeks', b'every-2-weeks')]),
        ),
    ]
