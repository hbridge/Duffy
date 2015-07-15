# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0063_auto_20150715_2122'),
    ]

    operations = [
        migrations.AlterField(
            model_name='zipdata',
            name='state',
            field=models.CharField(max_length=100),
        ),
    ]
