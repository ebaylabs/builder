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


def gitUpdate(uri, repoDir, logfile):
	gitCheckout('master', repoDir, logfile)
	cmd = ['git', 'pull', uri]
	p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logfile, cwd=repoDir)
	p.wait()

def gitClone(uri, repoDir, logfile):
    cmd = ['git', 'clone', uri]
    p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logfile, cwd=repoDir)
    p.wait()

def gitCheckout(path, repoDir, logfile):
	cmd = ['git', 'checkout', '-f', path]
	p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logfile, cwd=repoDir)
	p.wait()

def install(cwd, logfile):
	cmd = ['python', 'setup.py', 'build', 'sdist']
	p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logfile, cwd=cwd)
	p.wait()

def createVenv(path, logfile, cwd):
	cmd = [u'./scripts/create_venv', path]
	p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logfile, cwd=cwd)
	p.wait()

def installWithVenv(package, venv, logfile, cwd):
	cmd = [u'./scripts/install_in_venv', package, venv]
	p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logfile, cwd=cwd)
	p.wait()

def createPackage(path, fpmCmd, debUrl, logfile, cwd):
	cmd = [u'./scripts/create_package', path, fpmCmd, debUrl]
	p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logfile, cwd=cwd)
	p.wait()

cwd = os.getcwd()
config = readConfig("../packages/debian/keystone/c3-python-keystone/buildspec.yml")

p.log(str(config))

maintainer = config.get("maintainer")
packageName = config.get("name")
packageVersion = config.get("version")
pipRequires = config.get("pip-requires")
debianDeps = config.get("debian-dependencies")
debPackageUrl = config.get("deb-package-url")

logfileName = "%s.log" % (packageName)

logfile = open(logfileName, 'w+')
logfile.write(p.info("Building '%s' version '%s'" % (packageName, packageVersion)))

buildDir = ".build/opt/%s/%s" % (packageName, packageVersion)

if not os.path.isdir(buildDir):
	os.makedirs(buildDir)

p.log("Creating virtualenv in %s/%s" % ( cwd, buildDir ))
createVenv(buildDir, logfile, cwd)
	
for repo in config.get("git-repos"):
	''' remove https '''
	uri = repo.get('uri')
	repoName = uri[uri.rindex("/") + 1:-4]
	repoDir = "/tmp/c3build/" + uri[8:uri.rindex("/")]
	repoPath = repoDir + "/" + repoName
	if os.path.isdir(repoDir):
		gitUpdate(uri, repoPath, logfile)
	else:
		logfile.write("Creating directory %s for cloning" % (repo))
		os.makedirs(repoDir)
		logfile.write(p.log("Cloning '%s' under '%s'" % (uri, repoDir)))
		gitClone(uri, repoDir, logfile)
	path = repo.get('path')
	gitCheckout(str(path), repoPath, logfile)
	install(repoPath, logfile)
        package_tar = subprocess.check_output(["ls", repoPath + "/dist/"])
        tar = repoPath + '/dist/' + package_tar
	installWithVenv(tar, cwd + "/" + buildDir, logfile, cwd)

for pip_dep in pipRequires:
	installWithVenv(pip_dep, cwd + "/" + buildDir, logfile, cwd) 

# def createPackage(path, fpmCmd, debUrl, logfile, cwd):
createPackage(cwd + "/.build", "ls", debPackageUrl, logfile, cwd)

logfile.close()

p.info("Detailed log in %s" % cwd + "/" + logfileName)
