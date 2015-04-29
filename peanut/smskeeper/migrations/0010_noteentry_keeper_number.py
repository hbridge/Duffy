# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0009_noteentry_reminded'),
    ]

    operations = [
        migrations.AddField(
            model_name='noteentry',
            name='keeper_number',
            field=models.CharField(max_length=100, null=True),
            preserve_default=True,
        ),
    ]
