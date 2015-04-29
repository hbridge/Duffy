# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0008_noteentry_remind_timestamp'),
    ]

    operations = [
        migrations.AddField(
            model_name='noteentry',
            name='reminded',
            field=models.BooleanField(default=False),
            preserve_default=True,
        ),
    ]
