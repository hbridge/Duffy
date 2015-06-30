# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0046_auto_20150624_1737'),
    ]

    operations = [
        migrations.AddField(
            model_name='entry',
            name='manually_updated',
            field=models.BooleanField(default=False),
            preserve_default=True,
        ),
    ]
