# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0069_entry_created_from_entry_id'),
    ]

    operations = [
        migrations.AlterField(
            model_name='entry',
            name='created_from_entry_id',
            field=models.IntegerField(null=True, blank=True),
        ),
    ]
