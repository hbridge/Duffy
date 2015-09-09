# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0087_zipdata_temp_format'),
    ]

    operations = [
        migrations.AddField(
            model_name='message',
            name='manually_approved_timestamp',
            field=models.DateTimeField(null=True, blank=True),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='message',
            name='manually_check',
            field=models.BooleanField(default=False),
            preserve_default=True,
        ),
    ]
