# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0057_message_auto_classification'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='last_paused_timestamp',
            field=models.DateTimeField(null=True, blank=True),
            preserve_default=True,
        ),
    ]
