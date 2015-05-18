# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0028_auto_20150515_1611'),
    ]

    operations = [
        migrations.CreateModel(
            name='Reminder',
            fields=[
            ],
            options={
                'proxy': True,
            },
            bases=('smskeeper.entry',),
        ),
        migrations.AddField(
            model_name='entry',
            name='orig_text',
            field=models.TextField(null=True),
            preserve_default=True,
        ),
    ]
