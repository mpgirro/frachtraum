

# author: Maximilian Irro <max@disposia.org>, 2014

require 'mkmf' # part of stdlib
require 'open3'
require 'highline/import'
require 'parseconfig'

module Frachtraum
  
  VERSION = '0.0.1'
  
  CONFIG_FILE = '../frachtraum.conf.example'
  
  if File.exists?(CONFIG_FILE)
    config = ParseConfig.new(CONFIG_FILE)
    DEFAULT_COMPRESSION = config['compression']
    DEFAULT_ENCRYPTION  = config['encryption']
    DEFAULT_KEYLENGTH   = config['keylength']
    DEFAULT_MOUNTPOINT  = config['mountpoint']
  else
    DEFAULT_COMPRESSION = 'lz4'
    DEFAULT_ENCRYPTION  = 'AES-XTS'
    DEFAULT_KEYLENGTH   = 4096
    DEFAULT_MOUNTPOINT  = '/frachtraum'
  end
  
  REQUIRED_TOOLS_BSD   = ['dd','gpart','glabel','geli','zfs','zpool']
  REQUIRED_TOOLS_LINUX = [] # not yet supported
  
  
  def exec_cmd(cmd)
    Open3.popen2e(cmd) do |stdin, stdout_err, wait_thr|
      exit_status = wait_thr.value
      unless exit_status.success?
        abort "FAILED! -- Reason: #{stdout_err}"
      end
    end
  end # exec_cmd
  

  
  module_function # all following methods will be callable from outside the module
  
  def get_password(prompt="Enter Password")
     ask(prompt) {|q| q.echo = false}
  end
  
  def attach_bsd(password,depot)
    
  end
  
  def attach_linux(password,depot)
    # TODO
    abort "not yet implemented"
  end
  
  def setupdisk_bsd(dev, label, compression, encryption, keylength, mountpoint)
    
    # TODO password promt, confirmation question, etc..
    abort "implementation not ready yet"
    
    password1 = get_password("enter the encryption password: ")
    password2 = get_password("enter password again: ")
    if password1.match(password2)
      password = password1
    else
      abort "passwords not equal!"
    end

    print "destroying previous partitioning on /dev/#{dev}..."
    exec_cmd "dd if=/dev/zero of=/dev/#{dev} bs=512 count=1"
    puts "done"
    
    print "creating gpart container on /dev/#{dev}..."
    exec_cmd "gpart create -s GPT #{dev}"
    puts "done"
    
    print "labeling /dev/#{dev} with '#{label}'..."
    exec_cmd "glabel label -v #{label} /dev/#{dev}"
    puts "done"
    
    print "initialising /dev/#{dev} as password protected GEOM provider with #{encryption} encryption..."
    exec_cmd "echo #{password} | geli init -s #{keylength} -e #{encryption} -J - /dev/label/#{label}"
    puts "done"
    
    print "attaching /dev/label/#{label} as GEOM provider, creating device /dev/label/#{label}.eli..."
    exec_cmd "echo #{password} | geli attach -d -j - /dev/label/#{label}"
    puts "done"
    
    print "creating zpool #{mountpoint}/#{label} on encrypted device /dev/label/#{label}.eli..."
    exec_cmd "zpool create -m #{mountpoint}/#{label} #{label} /dev/label/#{label}.eli"
    puts "done"
    
    print "setting compression '#{compression}' for new zfs on #{mountpoint}/#{label}..."
    exec_cmd "zfs set compression=#{compression} #{label}" 
    puts "done"
    
    print "setting permissions..."
    exec_cmd "chmod -R 775 #{mountpoint}/#{label}"
    puts "done"
    
    puts "setup finished"
    
  end # setupdisk_bsd
  
  def setupdisk_linux(dev, label, compression, encryption, keylength, mountpoint)
    # TODO
    abort "not yet implemented"
  end # setupdisk_linux
  
  def run_system_test()
    tool_list = []  
    case RUBY_PLATFORM
      when /bsd/ then tool_list = REQUIRED_TOOLS_BSD
      when /linux/ then tool_list = REQUIRED_TOOLS_LINUX
      else raise InvalidOSError
    end
    
    tool_list.each do |tool|
      find_executable tool
    end
  end # run_system_test
  
end # Frachtraum



