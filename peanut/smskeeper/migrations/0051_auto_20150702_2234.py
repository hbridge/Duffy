# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0050_auto_20150702_1906'),
    ]

    operations = [
        migrations.DeleteModel(
            name='Todo',
        ),
        migrations.CreateModel(
            name='ToCheck',
            fields=[
            ],
            options={
                'proxy': True,
            },
            bases=('smskeeper.reminder',),
        ),
        migrations.AddField(
            model_name='entry',
            name='manually_check',
            field=models.BooleanField(default=False),
            preserve_default=True,
        ),
    ]
