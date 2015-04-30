# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0010_noteentry_keeper_number'),
    ]

    operations = [
        migrations.RenameField(
            model_name='noteentry',
            old_name='reminded',
            new_name='hidden',
        ),
    ]
