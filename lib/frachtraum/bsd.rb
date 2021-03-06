module Frachtraum

  REQUIRED_TOOLS_BSD = ['dd','grep','gpart','glabel','geli','zfs','zpool']

  def attach_bsd(password, volume=nil)

    # if we provided a specific depot, run procedure only on that one
    volumes = volume.nil? ? Frachtraum::VOLUMES : [ volume ]

    # first of all, decrypt and mount all depots
    volumes.each do |v|
      print "decrypting #{v}...".ljust(OUTPUT_DOTS_LEN,".")

      output = %x( echo #{password} | geli attach -d -j - /dev/label/#{v} 2>&1 )
      if $?.success?
        output = %x( zfs mount #{v} 2>&1 )
        if $?.success? then puts Rainbow(CHECKMARK).green
        else puts Rainbow("#{BALLOTX}\n#{output}").red end
      else
        puts Rainbow("#{BALLOTX}\n#{output}").red
      end
    end # volumes.each

    # mount timemachine targets as well
    Frachtraum::TIMEMACHINE_TARGETS.each do |tmtarget|
      print "mounting #{tmtarget}...".ljust(OUTPUT_DOTS_LEN,".")

      output = %x( zfs mount #{tmtarget} 2>&1 )
      if $?.success? then puts Rainbow(CHECKMARK).green
      else puts Rainbow("#{BALLOTX}\n#{output}").red end
    end

    # restart samba so it reports the correct pool size
    print "restarting samba server...".ljust(OUTPUT_DOTS_LEN,".")

    output = %x( /usr/local/etc/rc.d/samba restart 2>&1 )
    if $?.success? then puts Rainbow(CHECKMARK).green
    else puts Rainbow("#{BALLOTX}\n#{output}").red end
  end

  def setupdisk_bsd(dev, label, password, compression, encryption, keylength, mountpoint)

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

  # well, we need this line so attach can call attach_bsd
  # but I honestly don't know why...
  extend self

end
