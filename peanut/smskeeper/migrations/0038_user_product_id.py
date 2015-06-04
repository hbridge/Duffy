# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0037_auto_20150602_2309'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='product_id',
            field=models.IntegerField(default=0),
            preserve_default=True,
        ),
    ]
