# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0066_auto_20150720_2149'),
    ]

    operations = [
        migrations.AlterField(
            model_name='user',
            name='digest_minute',
            field=models.IntegerField(default=0),
        ),
    ]
