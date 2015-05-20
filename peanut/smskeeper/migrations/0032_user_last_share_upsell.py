# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0031_user_invite_code'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='last_share_upsell',
            field=models.DateTimeField(null=True),
            preserve_default=True,
        ),
    ]
