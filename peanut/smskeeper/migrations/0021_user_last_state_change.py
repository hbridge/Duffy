# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0020_merge'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='last_state_change',
            field=models.DateTimeField(null=True),
            preserve_default=True,
        ),
    ]
