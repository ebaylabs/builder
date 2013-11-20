#! /usr/bin/env python

from datetime import datetime

class Printer:
	
	PINK = '\033[95m'
	BLUE = '\033[94m'
	GREEN = '\033[92m'
	YELLOW = '\033[93m'
	FAIL = '\033[91m'
	GREY = '\033[90m'
	ENDC = '\033[0m'
	
	def pre(self):
		return self.GREY + "[ " + datetime.now().strftime("%Y-%m-%d %H:%M:%S") + " ] " + self.ENDC

	def info(self, msg):
		print self.pre() + self.PINK + msg + self.ENDC
	
	def warn(self, msg):
		print self.pre() + self.PINK + msg + self.ENDC

	def err(self, msg):
		print self.pre() + self.FAIL + msg + self.ENDC

	def log(self, msg):
		print self.pre() + msg

	def disable(self):
		self.HEADER = ''
		self.OKBLUE = ''
		self.OKGREEN = ''
		self.WARNING = ''
		self.FAIL = ''
