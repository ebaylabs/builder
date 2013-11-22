#! /usr/bin/env python

from datetime import datetime
import sys
import yaml
from subprocess import Popen
import subprocess
import os
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("buildspec", help="file containing build specification")
parser.add_argument("--debug", dest='debug',  action='store_true', help="run in debug mode")
args = parser.parse_args()

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

    def debug(self, msg):
        if args.debug:
            self.log(msg)

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
        p.debug(str(config))
        return config
try:
    config = readConfig(args.buildspec)
except IOError, e:
    p.err("Fatal: config file '%s' is not found." % args.buildspec)
    p.err("For usage, try 'build.py --help'") 
    sys.exit(-1)
except:
    p.err("fatal: config file '%s' can not be read or invalid." % args.buildspec)
    p.err("For usage, try 'build.py --help'") 
    sys.exit(-1)

#
# capture the config in local variables for ease of use
#
maintainer = config.get("maintainer")
package_name = config.get("name")
version = str(config.get("version"))
pip_requires = config.get("pip-requires")
debian_deps = config.get("debian-dependencies")
deb_url = config.get("deb-package-url")

def quit(msg):
    p.err(msg)
    p.err("Detailed log in %s" % (log))
    sys.exit(-1)

def git_pull(uri, repo_dir, logfile):
    git_checkout('master', repo_dir, logfile)
    cmd = ['git', 'pull', uri]
    p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logfile, cwd=repo_dir)
    p.wait()

def git_clone(uri, repo_dir, logfile):
    cmd = ['git', 'clone', uri]
    p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logfile, cwd=repo_dir)
    p.wait()

def git_checkout(path, repo_dir, logfile):
    cmd = ['git', 'checkout', '-f', path]
    p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logfile, cwd=repo_dir)
    p.wait()

def build(cwd, logfile):
    cmd = ['python', 'setup.py', 'build', 'sdist']
    p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logfile, cwd=cwd)
    p.wait()

'''
  creates virtual env.
  'cwd' is the directory from which the script passed is search for.
  'venv', the virtualenv to create
'''
def create_venv(venv, logfile, cwd):
    cmd = [u'./scripts/basher', 'CREATE_VENV', venv]
    p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logfile, cwd=cwd)
    p.wait()

def install(venv, package, logfile, cwd):
    cmd = [u'./scripts/basher', 'INSTALL', venv, package, version]
    p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logfile, cwd=cwd)
    p.wait()

def package(path, fpmCmd, debUrl, logfile, cwd):
    cmd = [u'./scripts/basher', path, fpmCmd, debUrl]
    p = Popen(cmd, stderr=subprocess.STDOUT, stdout=logfile, cwd=cwd)
    p.wait()

basedir = os.getcwd()
logdir = basedir + "/logs"
tmpdir = '/tmp/c3build'
builddir = tmpdir + '/' + package_name + '/' + version  + '/build'
debdir = tmpdir + '/' + package_name + '/' + version  + '/deb'
venv = builddir + '/venv'

if not os.path.isdir(logdir):
    os.mkdir(logdir)

logfileName = logdir + "/%s.log" % ( package_name + "_" + version )
logfile = open(logfileName, 'w+')

p.info("Building '%s' version '%s'" % (package_name, version))

if os.path.isdir(venv):
    p.log("Virtualenv exists.")
    p.debug("  Path: %s" % venv)
else:
    os.makedirs(venv)
    p.log("Creating virtualenv...");
    create_venv(venv, logfile, basedir)
    p.log("Virtualenv created: '%s'" % ( venv ))

if not os.path.isdir(debdir):
    os.makedirs(debdir)


''' install '''
for repo in config.get("git-repos"):
    ''' remove https '''
    uri = repo.get('uri')
    repo_name = uri[uri.rindex("/") + 1:-4]
    p.log("Installing %s'%s'%s" % (p.GREEN, repo_name, p.ENDC))
    repo_dir = builddir + '/' + uri[8:uri.rindex("/")]
    repo_path = repo_dir + '/' + repo_name
    if os.path.isdir(repo_path):
        p.log("  * Found repo. Pulling latest code.")
        p.debug("    Repo: %s." % repo_path)
        git_pull(uri, repo_path, logfile)
    else:
        p.debug("  * Creating directory %s for cloning" % (repo))
        os.makedirs(repo_dir)
        p.log("  * Cloning '%s' under '%s'" % (uri, repo_dir))
        git_clone(uri, repo_dir, logfile)
    path = repo.get('path')
    git_checkout(str(path), repo_path, logfile)
    p.log("  * Building '%s'" % (repo_name))
    p.debug("    using dir: '%s'" % (repo_path))
    build(repo_path, logfile)
    package_tar = subprocess.check_output(["ls", repo_path + "/dist/"]).rstrip('\n')
    tar = repo_path + '/dist/' + package_tar
    p.log("  * Installing '%s'" % package_tar)
    p.debug("    using tar: %s" % tar)
    install(venv, tar, logfile, basedir)

''' install all pip requirements '''
p.log("Installing " + p.GREEN + "pip dependencies" + p.ENDC)
for pip_dep in pip_requires:
    p.log("  * " + pip_dep)
    install(venv, pip_dep, logfile, basedir)

# package(cwd + "/.build", "ls", deb_url, logfile, cwd)
logfile.close()
p.info("Detailed log in %s" % logfileName)
