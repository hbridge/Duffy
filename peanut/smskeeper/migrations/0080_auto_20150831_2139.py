# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0079_auto_20150824_2123'),
    ]

    operations = [
        migrations.AddField(
            model_name='entry',
            name='last_state_change',
            field=models.DateTimeField(null=True, blank=True),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='entry',
            name='state',
            field=models.CharField(default=b'normal', max_length=100, choices=[(b'normal', b'normal'), (b'swept', b'swept')]),
            preserve_default=True,
        ),
    ]
