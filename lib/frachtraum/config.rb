
module Frachtraum
  
  case RUBY_PLATFORM
    when /bsd/    then CONFIG_FILE = "/usr/local/etc/frachtraum.conf"
    when /linux/  then CONFIG_FILE = "/usr/local/etc/frachtraum.conf" # is this correct?
    #when /darwin/ then setupdisk_osx   dev, label, password, compression, encryption, keylength, mountpoint
    else CONFIG_FILE = 'frachtraum.conf.example'
  end
  
  
  if File.exists?(CONFIG_FILE)
    config = ParseConfig.new(CONFIG_FILE)
    COMPRESSION = config['compression']
    ENCRYPTION  = config['encryption']
    KEYLENGTH   = config['keylength']
    MOUNTPOINT  = config['mountpoint']
  
    VOLUMES = config['volumes'].split(',')
    TIMEMACHINE_TARGETS = config['tmtargets'].split(',')
  else
    COMPRESSION = 'lz4'
    ENCRYPTION  = 'AES-XTS'
    KEYLENGTH   = 4096
    MOUNTPOINT  = '/frachtraum'
  
    VOLUMES = []
    TIMEMACHINE_TARGETS = []
  end
end

