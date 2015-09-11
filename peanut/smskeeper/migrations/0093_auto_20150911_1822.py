# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0092_auto_20150910_2251'),
    ]

    operations = [
        migrations.AlterField(
            model_name='simulationrun',
            name='sim_type',
            field=models.CharField(db_index=True, max_length=2, choices=[(b'pp', b'prodpush'), (b'dp', b'devpush'), (b't', b'test'), (b'nl', b'nightly')]),
        ),
    ]
