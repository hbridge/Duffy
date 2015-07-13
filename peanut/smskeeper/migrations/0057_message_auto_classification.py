# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0056_entry_remind_to_be_sent'),
    ]

    operations = [
        migrations.AddField(
            model_name='message',
            name='auto_classification',
            field=models.CharField(db_index=True, max_length=100, null=True, blank=True),
            preserve_default=True,
        ),
    ]
