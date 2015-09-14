# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0095_simulationrun_username'),
    ]

    operations = [
        migrations.AddField(
            model_name='simulationrun',
            name='annotation',
            field=models.TextField(null=True, blank=True),
            preserve_default=True,
        ),
    ]
