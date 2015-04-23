# -*- coding: utf-8 -*-
from __future__ import unicode_literals

from django.db import models, migrations


class Migration(migrations.Migration):

    dependencies = [
        ('smskeeper', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='IncomingMessage',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('msg_json', models.TextField(null=True)),
                ('user', models.ForeignKey(to='smskeeper.User')),
            ],
            options={
            },
            bases=(models.Model,),
        ),
        migrations.CreateModel(
            name='NoteEntry',
            fields=[
                ('id', models.AutoField(verbose_name='ID', serialize=False, auto_created=True, primary_key=True)),
                ('text', models.TextField(null=True)),
                ('img_urls_json', models.TextField(null=True)),
                ('note', models.ForeignKey(to='smskeeper.Note')),
            ],
            options={
            },
            bases=(models.Model,),
        ),
        migrations.RemoveField(
            model_name='note',
            name='text',
        ),
    ]
