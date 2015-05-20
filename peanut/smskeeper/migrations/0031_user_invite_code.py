# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0030_auto_20150518_1953'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='invite_code',
            field=models.CharField(max_length=100, null=True),
            preserve_default=True,
        ),
    ]
