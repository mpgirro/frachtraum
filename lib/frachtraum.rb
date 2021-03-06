

# author: Maximilian Irro <max@disposia.org>, 2014

require 'mkmf' # part of stdlib
require 'open3'
require 'parseconfig'

require 'frachtraum/config'
require 'frachtraum/cli'
require 'frachtraum/bsd'
require 'frachtraum/linux'
require 'frachtraum/osx'

module Frachtraum

  VERSION = '0.0.12'.freeze

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

  OUTPUT_DOTS_LEN = 40 # TODO: the length should be dynamically calculated, based on the strlen of longest tmtarget or volume


  CHECKMARK = "\u2713" # => ✓
  BALLOTX   = "\u2717" # => ✗

  def exec_cmd(msg, cmd)

    print msg

    Open3.popen2e(cmd) do |stdin, stdout_err, wait_thr|
      puts line while line = stdout_err.gets

      exit_status = wait_thr.value
      if exit_status.success?
        puts Rainbow("done").green
      else
        abort Rainbow("FAILED!").red + " --> #{stdout_err}"
      end
    end
  end # exec_cmd

  # ---------------

  def pretty_SI_bytes(bytes)
    return "%.1f TB" % (bytes.to_f / BYTES_IN_TB) if bytes > BYTES_IN_TB
    return "%.1f GB" % (bytes.to_f / BYTES_IN_GB) if bytes > BYTES_IN_GB
    return "%.1f MB" % (bytes.to_f / BYTES_IN_MB) if bytes > BYTES_IN_MB
    return "%.1f KB" % (bytes.to_f / BYTES_IN_KB) if bytes > BYTES_IN_KB
    return "#{bytes} B"
  end
  module_function :pretty_SI_bytes

  def pretty_IEC_bytes(bytes)
    return "%.1f TiB" % (bytes.to_f / BYTES_IN_TiB) if bytes > BYTES_IN_TiB
    return "%.1f GiB" % (bytes.to_f / BYTES_IN_GiB) if bytes > BYTES_IN_GiB
    return "%.1f MiB" % (bytes.to_f / BYTES_IN_MiB) if bytes > BYTES_IN_MiB
    return "%.1f KiB" % (bytes.to_f / BYTES_IN_KiB) if bytes > BYTES_IN_KiB
    return "#{bytes} B"
  end
  module_function :pretty_IEC_bytes

  def attach(password, volume=nil)
    case RUBY_PLATFORM
      when /bsd/    then attach_bsd   password, volume
      when /linux/  then attach_linux password, volume
      #when /darwin/ then attach_osx   password, volume
      else abort "OS not supported"
    end
  end
  module_function :attach

  def capacity()
    total_used  = 0
    total_avail = 0
    Frachtraum::VOLUMES.each do |volume|
      used  = %x( zfs get -o value -Hp used #{volume} 2>&1 )
      avail = %x( zfs get -o value -Hp available #{volume} 2>&1 )

      total_used  += (used =="" ? 0 : used).to_i  # / 1000 # 1024
      total_avail += (avail=="" ? 0 : avail).to_i # / 1000 # 1024
    end

    total = total_used + total_avail

    return {:total => total, :avail => total_avail, :used => total_used}
  end
  module_function :capacity

  def report()

    report_table = {}
    reported_values = [:used,:available,:compression,:compressratio]

    (Frachtraum::VOLUMES + Frachtraum::TIMEMACHINE_TARGETS).each do |dataset|
      volume_info = {}

      # fetch the values
      if zfs_volume_exists?(dataset)
        reported_values.each do |repval|
          volume_info[repval] = %x( zfs get -o value -Hp #{repval.to_s} #{dataset} )
        end
      else
        reported_values.each {|repval| volume_info[repval] = "N/A" }
      end

      # calculate a total size for each volume
      volume_info[:total] =
        if volume_info[:used]=="N/A" || volume_info[:available]=="N/A"
          "N/A"
        else
          (volume_info[:used].to_i + volume_info[:available].to_i)
        end

        volume_info[:usage] =
          if volume_info[:total] == 0
            "0 %"
          elsif volume_info[:used]=="N/A" || volume_info[:total]=="N/A"
            "N/A"
          elsif volume_info[:available].to_i == 0
            "100 %"
          else
            (100 * volume_info[:used].to_f / volume_info[:total].to_f ).to_i.to_s + " %"
          end

      report_table[dataset] = volume_info
    end

    return report_table
  end
  module_function :report


  def setupdisk(dev, label, password, compression, encryption, keylength, mountpoint)

    case RUBY_PLATFORM
      when /bsd/    then setupdisk_bsd   dev, label, password, compression, encryption, keylength, mountpoint
      when /linux/  then setupdisk_linux dev, label, password, compression, encryption, keylength, mountpoint
      #when /darwin/ then setupdisk_osx   dev, label, password, compression, encryption, keylength, mountpoint
      else abort "OS not supported"
    end
  end
  module_function :setupdisk

  def sweep(volume)

    target_volumes = volume.nil? ? Frachtraum::VOLUMES : volume

    # TODO
    abort "sweeping not supported yet"

    target_volumes.each do |volume|
      if zfs_volume_exists?(volume)
        # TODO
      end
    end
  end
  module_function :sweep


  def run_system_test()
    tool_list = []
    case RUBY_PLATFORM
      when /bsd/    then tool_list = REQUIRED_TOOLS_BSD
      when /linux/  then tool_list = REQUIRED_TOOLS_LINUX
      #when /darwin/ then tool_list = REQUIRED_TOOLS_OSX
      else abort "OS not supported"
    end

    tool_list.each { |tool| find_executable tool }

    # find_executable seems to create such file in case executable is not found
    File.delete 'mkmf.log' if File.exists?('mkmf.log')
  end # run_system_test
  module_function :run_system_test


  def zfs_volume_exists?(dataset)
    output = %x( zfs get -H mounted #{dataset} 2>&1 )
    case output
    when /yes/
      return true
    when /dataset does not exist/, /permission denied/
      return false
    else
      abort "can't handle output of zfs_volume_exists?: #{output}"
    end
  end
  module_function :zfs_volume_exists?

end # Frachtraum
