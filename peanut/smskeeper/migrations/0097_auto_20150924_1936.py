# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0096_simulationrun_annotation'),
    ]

    operations = [
        migrations.AddField(
            model_name='historicaluser',
            name='zendesk_id',
            field=models.IntegerField(null=True, blank=True),
            preserve_default=True,
        ),
        migrations.AddField(
            model_name='user',
            name='zendesk_id',
            field=models.IntegerField(null=True, blank=True),
            preserve_default=True,
        ),
    ]
