#! /usr/bin/env python

from datetime import datetime
import sys
import yaml
from subprocess import Popen
import subprocess
import os


class Printer:
	PINK = '\033[95m'
	BLUE = '\033[94m'
	GREEN = '\033[92m'
	YELLOW = '\033[93m'
	FAIL = '\033[91m'
	GREY = '\033[90m'
	ENDC = '\033[0m'
	
	def pre(self):
		return self.GREY + "[" + datetime.now().strftime("%Y-%m-%d %H:%M:%S") + "] " + self.ENDC

	def info(self, msg):
		print self.pre() + self.PINK + msg + self.ENDC
		return self.pre() + msg + "\n"
	
	def warn(self, msg):
		print self.pre() + self.PINK + msg + self.ENDC
		return self.pre() + msg + "\n"

	def err(self, msg):
		print self.pre() + self.FAIL + msg + self.ENDC
		return self.pre() + msg + "\n"

	def log(self, msg):
		print self.pre() + msg
		return self.pre() + msg + "\n"

	def disable(self):
		self.HEADER = ''
		self.OKBLUE = ''
		self.OKGREEN = ''
		self.WARNING = ''
		self.FAIL = ''


p = Printer()

def readConfig(configFile):
	with open(configFile) as f:
		config = yaml.load(f)
		return config

log = "/log"

def quit(msg):
	p.err(msg)
	p.err("Detailed log in %s" % (log))
	sys.exit(-1)


def gitUpdate(uri, repoDir, logFile):
	gitCheckout('master', repoDir, logFile)
	cmd = ['git', 'pull', uri]
	p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logFile, cwd=repoDir)
	p.wait()

def gitClone(uri, repoDir, logFile):
    cmd = ['git', 'clone', uri]
    p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logFile, cwd=repoDir)
    p.wait()

def gitCheckout(commit, repoDir, logFile):
    cmd = ['git', 'checkout', '-f', commit]
    p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logFile, cwd=repoDir)
    p.wait()

config = readConfig("/Users/pkaliyamurthy/Stack/buildr/packages/debian/keystone/c3-python-keystone/buildspec.yml")

print config

maintainer = config.get("maintainer")
packageName = config.get("name")
packageVersion = config.get("version")
pipRequires = config.get("pip-requires")
debianDeps = config.get("debian-dependencies")
debPackageUrl = config.get("deb-package-url")


logfile = open("%s.log" % (packageName), 'w')
logfile.write(p.info("Building '%s' version '%s'" % (packageName, packageVersion)))



for repo in config.get("git-repos"):
	''' remove https '''
	uri = repo.get('uri')
	repoDir = "/tmp/" + uri[8:4]
	print repoDir
	if os.path.isdir(repoDir):
		gitUpdate(uri, repoDir, logfile)
	else:
		logfile.write("Creating directory %s for cloning" % (repo))
		os.makedirs(repoDir)
		logfile.write(p.log("Cloning '%s' under '%s'" % (uri, repoDir)))
		gitClone(uri, repoDir, logfile)
logfile.close() 
quit("Awesome")
