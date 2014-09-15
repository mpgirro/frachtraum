

# author: Maximilian Irro <max@disposia.org>, 2014

require 'mkmf' # part of stdlib
require 'open3'
require 'highline/import'
require 'parseconfig'

module Frachtraum
  
  VERSION = '0.0.1'
  
  CONFIG_FILE = 'frachtraum.conf.example'
  
  if File.exists?(CONFIG_FILE)
    config = ParseConfig.new(CONFIG_FILE)
    COMPRESSION = config['compression']
    ENCRYPTION  = config['encryption']
    KEYLENGTH   = config['keylength']
    MOUNTPOINT  = config['mountpoint']
    
    DEPOTS = config['depots'].split(',')
    TIMEMACHINE_TARGETS = config['tmtargets'].split(',')
  else
    COMPRESSION = 'lz4'
    ENCRYPTION  = 'AES-XTS'
    KEYLENGTH   = 4096
    MOUNTPOINT  = '/frachtraum'
    
    DEPOTS = []
    TIMEMACHINE_TARGETS = []
  end
  
  REQUIRED_TOOLS_BSD   = ['dd','gpart','glabel','geli','zfs','zpool']
  REQUIRED_TOOLS_LINUX = [] # not yet supported
  
  # Kibibyte, Mebibyte, Gibibyte, etc... all the IEC sizes
  BYTES_IN_KiB = 2**10
  BYTES_IN_MiB = 2**20
  BYTES_IN_GiB = 2**30
  BYTES_IN_TiB = 2**40

  # these define a KB as 1000 bits, according to the SI prefix 
  BYTES_IN_KB = 10**3
  BYTES_IN_MB = 10**6
  BYTES_IN_GB = 10**9
  BYTES_IN_TB = 10**12
  
  
  def exec_cmd(msg, cmd)
    
    print msg
    
    Open3.popen2e(cmd) do |stdin, stdout_err, wait_thr|
      puts line while line = stdout_err.gets
      
      exit_status = wait_thr.value
      if exit_status.success?
        puts "done"
      else
        abort "FAILED! --> #{stdout_err}"
      end
    end
  end # exec_cmd
  
  
  module_function # all following methods will be callable from outside the module
  
  def pretty_SI_bytes(bytes)
    return "%.1f TB" % (bytes.to_f / BYTES_IN_TB) if bytes > BYTES_IN_TB
    return "%.1f GB" % (bytes.to_f / BYTES_IN_GB) if bytes > BYTES_IN_GB
    return "%.1f MB" % (bytes.to_f / BYTES_IN_MB) if bytes > BYTES_IN_MB
    return "%.1f KB" % (bytes.to_f / BYTES_IN_KB) if bytes > BYTES_IN_KB
    return "#{bytes} B"
  end
  
  def pretty_IEC_bytes(bytes)
    return "%.1f TiB" % (bytes.to_f / BYTES_IN_TiB) if bytes > BYTES_IN_TiB
    return "%.1f GiB" % (bytes.to_f / BYTES_IN_GiB) if bytes > BYTES_IN_GiB
    return "%.1f MiB" % (bytes.to_f / BYTES_IN_MiB) if bytes > BYTES_IN_MiB
    return "%.1f KiB" % (bytes.to_f / BYTES_IN_KiB) if bytes > BYTES_IN_KiB
    return "#{bytes} B"
  end
  
  
  def get_password(prompt="Enter Password")
     ask(prompt) {|q| q.echo = false}
  end
  
  def attach_bsd(depot=nil)
    
    # if we provided a specific depot, run procedure only on that one
    depots = depot.nil? ? DEPOTS : [ depot ]
    
    password = get_password
    
    # first of all, decrypt and mount all depots
    depots.each do |depot|      
      print "decrypting /dev/label/#{depot}..."
      
      output = %x( echo #{password} | geli attach -d -j - /dev/label/#{depot} 2>&1 )
      if $?.success? 
        output = %x( zfs mount #{depot} 2>&1 )
        if $?.success? then puts "DONE"
        else puts "FAILED! --> #{output}" end
      else 
        puts "FAILED! --> #{output}" 
      end
    end # each
    
    # mount timemachine targets as well
    TIMEMACHINE_TARGETS.each do |tmtarget|
      print "mounting timemachine target #{tmtarget}..."

      output = %x( zfs mount #{tmtarget} 2>&1 )
      if $?.success? then puts "DONE"
      else puts "FAILED! --> #{output}" end
    end
    
    # restart samba so it reports the correct pool size
    print "restarting samba server..."
    output = %x( /usr/local/etc/rc.d/samba restart 2>&1 )
    if $?.success? then puts "DONE"
    else puts "FAILED! --> #{output}" end
  end
  
  def attach_linux(depot)
    # TODO
    abort "not yet implemented"
  end
  
  
  def capacity()
    total_used  = 0
    total_avail = 0
    DEPOTS.each do |depot|
      used  = %x( zfs get -o value -Hp used #{MOUNTPOINT}/#{depot} )
      avail = %x( zfs get -o value -Hp available #{MOUNTPOINT}/#{depot} )
      
      total_used  += (used =="" ? 0 : used)  / 1000 # 1024
      total_avail += (avail=="" ? 0 : avail) / 1000 # 1024
    end
    
    total = total_used + total_avail
    
    return {:total => total, :avail => total_avail, :used => total_used}
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
    
    # TODO promt for confirmation!!

    exec_cmd "destroying previous partitioning on /dev/#{dev}...", 
             "dd if=/dev/zero of=/dev/#{dev} bs=512 count=1"
    
    exec_cmd "creating gpart container on /dev/#{dev}...", 
             "gpart create -s GPT #{dev}"

    exec_cmd "labeling /dev/#{dev} with '#{label}'...", 
             "glabel label -v #{label} /dev/#{dev}"

    exec_cmd "initialising /dev/#{dev} as password protected GEOM provider with #{encryption} encryption...",
             "echo #{password} | geli init -s #{keylength} -e #{encryption} -J - /dev/label/#{label}"
 
    exec_cmd "attaching /dev/label/#{label} as GEOM provider, creating device /dev/label/#{label}.eli...", 
             "echo #{password} | geli attach -d -j - /dev/label/#{label}"

    exec_cmd "creating zpool #{mountpoint}/#{label} on encrypted device /dev/label/#{label}.eli...", 
             "zpool create -m #{mountpoint}/#{label} #{label} /dev/label/#{label}.eli"

    exec_cmd "setting compression '#{compression}' for new zfs on #{mountpoint}/#{label}...", 
             "zfs set compression=#{compression} #{label}" 

    exec_cmd "setting permissions...", 
             "chmod -R 775 #{mountpoint}/#{label}"

    puts "setup finished"
    
  end # setupdisk_bsd
  
  def setupdisk_linux(dev, label, compression, encryption, keylength, mountpoint)
    # TODO
    abort "not yet implemented"
  end # setupdisk_linux
  
  def run_system_test()
    tool_list = []  
    case RUBY_PLATFORM
      when /bsd/   then tool_list = REQUIRED_TOOLS_BSD
      when /linux/ then tool_list = REQUIRED_TOOLS_LINUX
      else abort "OS not supported"
    end
    
    tool_list.each do |tool|
      find_executable tool
    end
    
    # find_executable seems to create such file in case executable is not found
    File.delete 'mkmf.log' if File.exists?('mkmf.log')
  end # run_system_test
  
end # Frachtraum



