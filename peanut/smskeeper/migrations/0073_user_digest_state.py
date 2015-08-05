# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0072_auto_20150805_1925'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='digest_state',
            field=models.CharField(default=b'default', max_length=20, choices=[(b'default', b'default'), (b'limited', b'limited')]),
            preserve_default=True,
        ),
    ]
