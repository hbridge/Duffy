# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0044_verbdata'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='entry',
            name='keeper_number',
        ),
    ]
