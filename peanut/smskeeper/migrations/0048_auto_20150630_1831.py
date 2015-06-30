# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0047_entry_manually_updated'),
    ]

    operations = [
        migrations.AddField(
            model_name='entry',
            name='manually_updated_timestamp',
            field=models.DateTimeField(null=True, blank=True),
            preserve_default=True,
        ),
        migrations.AlterField(
            model_name='entry',
            name='users',
            field=models.ManyToManyField(db_index=True, related_name=b'users', null=True, to=b'smskeeper.User', blank=True),
        ),
    ]
