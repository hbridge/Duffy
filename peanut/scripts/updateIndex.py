import datetime
import sys
import subprocess
import time

def main(argv):
	while True:
		dt = datetime.datetime.utcnow() - datetime.timedelta(seconds=60)
		timeStr = dt.strftime("%Y-%m-%dT%H:%M:%S")
		subprocess.call("python /home/derek/prod/Duffy/peanut/manage.py update_index --start=" + timeStr, shell=True)
		time.sleep(1)

if __name__ == "__main__":
	main(sys.argv[1:])