

# author: Maximilian Irro <max@disposia.org>, 2014

require 'mkmf' # part of stdlib

module Frachtraum
  
  VERSION = '0.0.1'
  CONFIG_FILE = '~/.frachtraumrc'
  DEFAULT_KEYLENGTH = 4096
  DEFAULT_ENCRYPTION = 'AES-XTS'
  DEFAULT_COMPRESSION = 'lz4'
  
  module_function # all following methods will be callable from outside the module
  
  def run_system_test()
    find_executable 'dd'
    find_executable 'gpart'
    find_executable 'glabel'
    find_executable 'geli'
    find_executable 'zfs'
    find_executable 'zpool'
  end
  
end # Frachtraum



