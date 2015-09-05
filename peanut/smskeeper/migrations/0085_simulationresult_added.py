# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0084_auto_20150905_1518'),
    ]

    operations = [
        migrations.AddField(
            model_name='simulationresult',
            name='added',
            field=models.DateTimeField(db_index=True, auto_now_add=True, null=True),
            preserve_default=True,
        ),
    ]
