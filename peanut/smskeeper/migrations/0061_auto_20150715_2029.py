# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0060_entry_remind_recur_end'),
    ]

    operations = [
        migrations.RenameField(
            model_name='zipdata',
            old_name='zip_code',
            new_name='postal_code',
        ),
        migrations.AddField(
            model_name='zipdata',
            name='country_code',
            field=models.CharField(max_length=10, null=True),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='zipdata',
            name='wxcode',
            field=models.CharField(max_length=10, null=True),
            preserve_default=True,
        ),
    ]
