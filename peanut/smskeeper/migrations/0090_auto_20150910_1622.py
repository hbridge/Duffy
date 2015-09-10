# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0089_merge'),
    ]

    operations = [
        migrations.AlterField(
            model_name='entry',
            name='updated',
            field=models.DateTimeField(null=True, db_index=True),
        ),
        migrations.AlterField(
            model_name='historicalentry',
            name='updated',
            field=models.DateTimeField(null=True, db_index=True),
        ),
    ]
