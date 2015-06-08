# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0040_auto_20150605_2252'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='last_feedback_prompt',
            field=models.DateTimeField(null=True, blank=True),
            preserve_default=True,
        ),
    ]
