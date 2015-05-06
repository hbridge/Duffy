# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0018_user_sent_tips'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='last_tip_sent',
            field=models.DateTimeField(null=True),
            preserve_default=True,
        ),
    ]
