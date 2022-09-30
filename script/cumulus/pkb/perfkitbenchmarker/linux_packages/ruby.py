from perfkitbenchmarker import errors
from absl import flags
import logging


FLAGS = flags.FLAGS

flags.DEFINE_string('ruby_version', '2.7',
                    'Version of ruby to be installed')
EMON_MAIN_DIR = '/opt/emon'


def _Install(vm):
  cmds = ['curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -',
          'curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import -',
          'curl -L get.rvm.io | bash -s stable',
          'sed -i "1 i\source $HOME/.rvm/scripts/rvm" ~/.bashrc']
  vm.RemoteCommand(' && '.join(cmds))
  cmds = ['rvm reload',
          'rvm requirements run',
          'rvm install {0} '.format(FLAGS.ruby_version)]
  vm.RemoteCommand(' && '.join(cmds))


def _CompatibleRubyVersion(vm):
  installed_ruby_version = vm.RemoteCommand("ruby -v | awk -F' ' '{{print $2}}'")[0].rstrip("\n")
  # If apt or yum downloads a compatible version,  then don't download rvm
  logging.info("Installed Version: {}, Version Needed: {}"
               .format(installed_ruby_version, FLAGS.ruby_version))
  if FLAGS.ruby_version in installed_ruby_version:
    return True
  vm.RemoteCommand('sudo touch {0}/pkb_ruby_file'.format(EMON_MAIN_DIR))
  return False


def YumInstall(vm):
  """Installs the package on the VM."""
  vm.RemoteCommand('sudo yum install -y ruby')
  if not _CompatibleRubyVersion(vm):
    logging.info("Installing a newer compatible verison of ruby")
    vm.InstallPackages('gcc-c++ patch readline readline-devel zlib zlib-devel libffi-devel '
                       'openssl-devel make bzip2 autoconf automake libtool bison sqlite-devel')
    _Install(vm)


def AptInstall(vm):
  """Installs the package on the VM."""
  vm.RemoteCommand('sudo apt-get install -y ruby')
  if not _CompatibleRubyVersion(vm):
    logging.info("Installing a newer compatible verison of ruby")
    vm.InstallPackages('gnupg2 curl g++ gcc autoconf automake bison libc6-dev libffi-dev '
                       'libgdbm-dev libncurses5-dev libsqlite3-dev libtool libyaml-dev make '
                       'pkg-config sqlite3 zlib1g-dev libgmp-dev libreadline-dev libssl-dev')
    _Install(vm)
