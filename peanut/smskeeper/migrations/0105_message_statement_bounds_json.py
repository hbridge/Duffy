# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0104_auto_20151002_2001'),
    ]

    operations = [
        migrations.AddField(
            model_name='message',
            name='statement_bounds_json',
            field=models.TextField(null=True),
            preserve_default=True,
        ),
    ]
