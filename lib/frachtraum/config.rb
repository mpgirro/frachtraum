
module Frachtraum
  
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
end

