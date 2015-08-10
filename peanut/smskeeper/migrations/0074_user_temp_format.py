# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0073_user_digest_state'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='temp_format',
            field=models.CharField(default=b'imperial', max_length=10),
            preserve_default=True,
        ),
    ]
