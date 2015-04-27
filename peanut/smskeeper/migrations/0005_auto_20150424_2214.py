# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0004_auto_20150424_1811'),
    ]

    operations = [
        migrations.CreateModel(
            name='Message',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('msg_json', models.TextField(null=True)),
                ('incoming', models.BooleanField()),
                ('added', models.DateTimeField(db_index=True, auto_now_add=True, null=True)),
                ('updated', models.DateTimeField(db_index=True, auto_now=True, null=True)),
                ('user', models.ForeignKey(to='smskeeper.User')),
            ],
            options={
            },
            bases=(models.Model,),
        ),
        migrations.RemoveField(
            model_name='incomingmessage',
            name='user',
        ),
        migrations.DeleteModel(
            name='IncomingMessage',
        ),
    ]
