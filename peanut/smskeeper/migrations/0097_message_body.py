# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0096_simulationrun_annotation'),
    ]

    operations = [
        migrations.AddField(
            model_name='message',
            name='body',
            field=models.CharField(max_length=700, null=True),
            preserve_default=True,
        ),
    ]
