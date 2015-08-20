# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0077_auto_20150817_1839'),
    ]

    operations = [
        migrations.RenameField(
            model_name='entry',
            old_name='is_default_time_and_date',
            new_name='use_digest_time',
        ),
    ]
