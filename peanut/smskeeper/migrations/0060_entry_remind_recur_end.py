# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0059_entry_is_default_time_and_date'),
    ]

    operations = [
        migrations.AddField(
            model_name='entry',
            name='remind_recur_end',
            field=models.DateTimeField(null=True, blank=True),
            preserve_default=True,
        ),
    ]
