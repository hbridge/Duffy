# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0007_auto_20150428_1918'),
    ]

    operations = [
        migrations.AddField(
            model_name='noteentry',
            name='remind_timestamp',
            field=models.DateTimeField(null=True),
            preserve_default=True,
        ),
    ]
