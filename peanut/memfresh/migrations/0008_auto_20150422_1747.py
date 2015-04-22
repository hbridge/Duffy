# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('memfresh', '0007_auto_20150422_1742'),
    ]

    operations = [
        migrations.AlterField(
            model_name='user',
            name='added',
            field=models.DateTimeField(db_index=True, auto_now_add=True, null=True),
        ),
        migrations.AlterField(
            model_name='user',
            name='updated',
            field=models.DateTimeField(db_index=True, auto_now=True, null=True),
        ),
    ]
