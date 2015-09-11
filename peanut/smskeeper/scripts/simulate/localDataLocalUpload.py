# to run use ./manage.py test smskeeper.scripts.simulateClassifiedMessages
from smskeeper.scripts.simulate import simulation


class SMSKeeperLocalSimulationCase(simulation.SMSKeeperSimulationCase):
	SIMULATION_CONFIGURATION = {
		'message_source': 'l',  # messages are local
		'sim_type': 't',  # test
		'classified_messages_url': "http://localhost:7500/smskeeper/classified_messages_feed/",
		'post_results_url': "http://localhost:7500/smskeeper/simulation_run/"
	}
