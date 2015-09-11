# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0093_auto_20150911_1822'),
    ]

    operations = [
        migrations.AlterField(
            model_name='message',
            name='added',
            field=models.DateTimeField(null=True, db_index=True),
        ),
        migrations.AlterField(
            model_name='message',
            name='updated',
            field=models.DateTimeField(null=True, db_index=True),
        ),
    ]
