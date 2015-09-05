# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0085_simulationresult_added'),
    ]

    operations = [
        migrations.AlterField(
            model_name='simulationresult',
            name='git_revision',
            field=models.CharField(max_length=7, db_index=True),
        ),
    ]
