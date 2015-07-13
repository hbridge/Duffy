# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0055_entry_remind_recur'),
    ]

    operations = [
        migrations.AddField(
            model_name='entry',
            name='remind_to_be_sent',
            field=models.BooleanField(default=True, db_index=True),
            preserve_default=True,
        ),
    ]
