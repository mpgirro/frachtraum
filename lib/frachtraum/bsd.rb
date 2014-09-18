module Frachtraum
  
  REQUIRED_TOOLS_BSD   = ['dd','grep','gpart','glabel','geli','zfs','zpool']
  
  
  def attach_bsd(password, depot=nil)
    
    # if we provided a specific depot, run procedure only on that one
    depots = depot.nil? ? DEPOTS : [ depot ]
    
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
  
  def setupdisk_bsd(dev, label, password, compression, encryption, keylength, mountpoint)
    
    # TODO password promt, confirmation question, etc..
    abort "implementation not ready yet"
    
    
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
  
end