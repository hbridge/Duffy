# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0027_zipdata'),
    ]

    operations = [
        migrations.AddField(
            model_name='zipdata',
            name='area_code',
            field=models.CharField(default='', max_length=10, db_index=True),
            preserve_default=False,
        ),
        migrations.AlterField(
            model_name='zipdata',
            name='zip_code',
            field=models.CharField(max_length=10, db_index=True),
        ),
    ]
