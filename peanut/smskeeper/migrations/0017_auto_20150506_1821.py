# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0016_contact_entry'),
    ]

    operations = [
        migrations.AlterField(
            model_name='entry',
            name='creator',
            field=models.ForeignKey(related_name=b'creator', to='smskeeper.User'),
        ),
        migrations.AlterField(
            model_name='entry',
            name='users',
            field=models.ManyToManyField(related_name=b'users', to=b'smskeeper.User', db_index=True),
        ),
    ]
