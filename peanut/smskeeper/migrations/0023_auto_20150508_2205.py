# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0022_merge'),
    ]

    operations = [
        migrations.AlterField(
            model_name='user',
            name='state_data',
            field=models.TextField(null=True),
        ),
    ]
