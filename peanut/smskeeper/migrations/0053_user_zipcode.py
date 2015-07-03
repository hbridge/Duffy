# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0052_entry_manually_approved_timestamp'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='zipcode',
            field=models.CharField(max_length=10, null=True, blank=True),
            preserve_default=True,
        ),
    ]
