# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0005_auto_20150424_2214'),
    ]

    operations = [
        migrations.AlterField(
            model_name='message',
            name='incoming',
            field=models.BooleanField(default=None),
        ),
    ]
