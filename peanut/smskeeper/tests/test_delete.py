def test_freeform_absolute_delete(self):
	self.setupUser(True, True, keeper_constants.STATE_NORMAL)

	cliMsg.msg(self.testPhoneNumber, "Add milk, spinach, bread to groceries")
	cliMsg.msg(self.testPhoneNumber, "Delete 1 from groceries")
	with patch('smskeeper.async.recordOutput') as mock:
		cliMsg.msg(self.testPhoneNumber, "Groceries")
		self.assertNotIn("milk", getOutput(mock))

def test_delete_parsing(self):
	self.assertTrue(msg_util.isDeleteCommand("delete 1"))
	self.assertTrue(msg_util.isDeleteCommand("delete 1 from groceries"))
	self.assertTrue(msg_util.isDeleteCommand("delete 1 #groceries"))

	label, indices = msg_util.parseDeleteCommand("delete 1")
	self.assertEqual(label, None)
	self.assertEqual(indices, set([1]))

	label, indices = msg_util.parseDeleteCommand("delete 1,2,3 from groceries")
	self.assertEqual(label, "#groceries")
	self.assertEqual(indices, set([1, 2, 3]))

def test_contextual_clear(self):
	self.setupUser(True, True)
	for i in range(1, 2):
		cliMsg.msg(self.testPhoneNumber, "foo%d #bar" % (i))

	# ensure we don't clear this list when we use an absolute of another list
	cliMsg.msg(self.testPhoneNumber, "bar")
	cliMsg.msg(self.testPhoneNumber, "clear baz")
	with patch('smskeeper.async.recordOutput') as mock:
		cliMsg.msg(self.testPhoneNumber, "bar")
		self.assertIn("foo", getOutput(mock))

	# clear now after we just listed bar
	cliMsg.msg(self.testPhoneNumber, "clear")
	with patch('smskeeper.async.recordOutput') as mock:
		cliMsg.msg(self.testPhoneNumber, "bar")
		self.assertNotIn("foo", getOutput(mock))