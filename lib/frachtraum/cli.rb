
require 'thor'
require 'highline/import'
require 'rainbow'
require 'terminal-table'

def prompt_password(prompt="Password: ")
  HighLine.ask(prompt) { |q| q.echo = false }
end

module Frachtraum
  
  class Frachtraum::CLI < Thor
  
    desc "attach [VOLUME]", "decrypt and mount volume(s)"
    long_desc <<-LONGDESC
      `frachtraum attach` will prompt you for a password.
    
      The password is used to decrypt all volume specified
      in #{Frachtraum::CONFIG_FILE}

      You can optionally specify a single volume. In this case
      only this volume will be decrypted and mounted.
    LONGDESC
    def attach(volume=nil)
    
      password = prompt_password
    
      Frachtraum.attach password, volume
    end
  
    # --------------
  
    desc "capacity [OPTION]", "show overall storage capacity"
    long_desc <<-LONGDESC
      `frachtraum capacity` will output capacity...

      lorem ipsum
    LONGDESC
    def capacity(option=nil)
      c = Frachtraum.capacity
    
      case option
      when "smb", "samba"
        puts "#{c[:total]/1000} #{c[:avail]/1000}"
      else
        puts ""
        puts "Capacity:"
        puts "    Available: #{Frachtraum.pretty_SI_bytes(c[:avail])}"
        puts "    Used:      #{Frachtraum.pretty_SI_bytes(c[:used])}"
        puts "    Total:     #{Frachtraum.pretty_SI_bytes(c[:total])}"
        puts ""
      end
    end
  
    # --------------
  
    desc "list", "list volumes and/or timemachine targets"
    long_desc <<-LONGDESC
      lorem ipsum
    LONGDESC
    option :simple, :type => :boolean
    def list(subset=nil)
    
      # TODO: this needs to be a constant, or calculated as CONST + max length of volume/tm
      list_width = 60 # character length of list

      if subset == "volume" || subset == "volumes" || subset.nil?
        if options[:simple]
          Frachtraum::VOLUMES.each{ |volume| puts volume }
        else
          puts "" # empty line
          puts "Volumes:"
          puts "" # empty line
          Frachtraum::VOLUMES.each{ |volume| 
            status = 
              if Frachtraum.zfs_volume_exists?(volume)
                Rainbow("attached").green
              else
                Rainbow("UNAVAILABLE").red
              end
            status = "[#{status}]".rjust(list_width-volume.length)
            puts "    #{volume}#{status}" 
          }
          puts "" # empty line
        end
      end
    
      if subset == "timemachine" || subset == "tm" || subset.nil?
        if options[:simple]
          Frachtraum::TIMEMACHINE_TARGETS.each{ |dataset| puts dataset }
        else
          puts "" unless subset.nil? # empty line
          puts "Timemachine targets:"
          puts "" # empty line
          Frachtraum::TIMEMACHINE_TARGETS.each{ |dataset| 
            status = 
              if Frachtraum.zfs_volume_exists?(dataset)
                Rainbow("attached").green
              else
                Rainbow("UNAVAILABLE").red
              end
            status = "[#{status}]".rjust(list_width-dataset.length)
            puts "    #{dataset}#{status}" 
          }
          puts "" # empty line
        end
      end 
    end
  
    # --------------
  
    desc "report", "Print a detailed report on your frachtraum"
    long_desc <<-LONGDESC
      lorem ipsum
    LONGDESC
    def report()
    
      report_rows = []
      report_data = Frachtraum.report
            
      report_data.keys.each do |volume|
        volume_h = report_data[volume]
        
        # display available output red if there is less then 10% space left on volume
        available_str = 
          if volume_h[:available].to_i <= 0.1 * volume_h[:total].to_i && volume_h[:total].to_i != 0
            Rainbow(Frachtraum.pretty_SI_bytes(volume_h[:available].to_i)).red
          else
            Frachtraum.pretty_SI_bytes(volume_h[:available].to_i)
          end 
        
        report_rows << [ volume, 
                         Frachtraum.pretty_SI_bytes(volume_h[:used].to_i), 
                         available_str, #Frachtraum.pretty_SI_bytes(volume_h[:available].to_i),
                         Frachtraum.pretty_SI_bytes(volume_h[:total].to_i), 
                         volume_h[:usage], # usage = used / total
                         volume_h[:compression], 
                         volume_h[:compressratio]
                       ]
      end
    
      # TODO
      table = Terminal::Table.new :headings => ["VOLUMES", "USED", "AVAILABLE", "TOTAL", "USAGE", "COMPRESSION", "COMPRESSRATIO"], :rows => report_rows
      
      table.align_column(1, :right)
      table.align_column(2, :right)
      table.align_column(3, :right)
      table.align_column(4, :right)
      
      puts table
      self.capacity
    
    end
  
    # --------------
  
    desc "setupdisk", "setup a device as a new volume"
    long_desc <<-LONGDESC
      `frachtraum setup dev label` will setup...
    
      lorem ispum
    LONGDESC
    options :compression => :string, :encryption => :string, :keylength => :integer, :mountpoint => :string
    def setupdisk(dev,label)
    
      compression = options[:compression] ? options[:compression] : Frachtraum::COMPRESSION
      encryption  = options[:encryption]  ? options[:encryption]  : Frachtraum::ENCRYPTION
      keylength   = options[:keylength]   ? options[:keylength]   : Frachtraum::KEYLENGTH
      mountpoint  = options[:mountpoint]  ? options[:mountpoint]  : Frachtraum::MOUNTPOINT
    
      password1 = prompt_password("enter encryption password: ")
      password2 = prompt_password("enter password again: ")
      if password1.match(password2)
        password = password1
      else
        abort "passwords not equal!"
      end
    
      puts ""
      puts "Device:      #{dev}"
      puts "Label:       #{label}"
      puts "Compression: #{compression}"
      puts "Encryption:  #{encryption}"
      puts "Keylength:   #{keylength}"
      puts "Mountpoint:  #{mountpoint}"
      puts ""
      puts "ATTENTION! This is a destructive action. All data on the device will be"
      puts "wiped. If you forget you password, you will not be able to access any"
      puts "containing data any more."
      puts ""
    
      answer = HighLine.ask("Are you sure you want to continue? (type 'yes'): ") { |q| q.echo = true }
    
      if answer.downcase.match("yes")
        Frachtraum.setupdisk dev, label, password, compression, encryption, keylength, mountpoint
      else
        abort "ABORT -- device will not pe processed!"
      end
    end
  
    # --------------
  
    desc "sweep [VOLUME]", "sweep the volumes!"
    long_desc <<-LONGDESC
      `frachtraum sweep` will ...

      lorem ipsum
    LONGDESC
    def sweep(volume=nil)
      Frachtraum.sweep volume
    end
  
    # --------------
  
    desc "test", "test system for compatibility"
    long_desc <<-LONGDESC
      `frachtraum test` will test...

      lorem ipsum
    LONGDESC
    def test()
      Frachtraum.run_system_test
    end
    
    # --------------
    
    desc "version", "print version information"
    def version()
      puts "frachtraum version" + Frachtraum::VERSION
    end
  end

end