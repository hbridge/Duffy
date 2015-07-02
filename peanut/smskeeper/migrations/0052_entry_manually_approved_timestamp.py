# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0051_auto_20150702_2234'),
    ]

    operations = [
        migrations.AddField(
            model_name='entry',
            name='manually_approved_timestamp',
            field=models.DateTimeField(null=True, blank=True),
            preserve_default=True,
        ),
    ]
