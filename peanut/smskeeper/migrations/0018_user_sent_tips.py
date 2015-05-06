# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0017_auto_20150506_1821'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='sent_tips',
            field=models.TextField(null=True),
            preserve_default=True,
        ),
    ]
