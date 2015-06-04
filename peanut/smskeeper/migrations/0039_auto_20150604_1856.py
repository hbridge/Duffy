# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0038_user_product_id'),
    ]

    operations = [
        migrations.CreateModel(
            name='Todo',
            fields=[
            ],
            options={
                'proxy': True,
            },
            bases=('smskeeper.reminder',),
        ),
        migrations.AddField(
            model_name='entry',
            name='remind_last_notified',
            field=models.DateTimeField(null=True, blank=True),
            preserve_default=True,
        ),
    ]
