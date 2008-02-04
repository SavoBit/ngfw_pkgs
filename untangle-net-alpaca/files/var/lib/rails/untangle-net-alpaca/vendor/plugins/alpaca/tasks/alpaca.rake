namespace :alpaca do
  EtcHostFile = "/etc/hosts"

  desc "Initialize the database for the untangle-net-alpaca"  
  task :init => :insert_system_rules

  desc "Load all of the system rules."
  task :insert_system_rules => "db:migrate" do
    Alpaca::SystemRules.insert_system_rules
  end

  desc "Restore all of the settings from the database"
  task :restore => :init do
    ## Reload all of the managers
    os = Alpaca::OS.current_os
    Dir.new( "#{RAILS_ROOT}/lib/os_library" ).each do |manager|
      next if /_manager.rb$/.match( manager ).nil?
      
      ## Load the manager for this os, this will complete all of the initialization at
      os["#{manager.sub( /.rb$/, "" )}"]
    end

    ## Commit the network settings only if there are interfaces setup.
    os["network_manager"].commit unless Interface.find( :first ).nil?
  end

  desc "Upgrade task for settings from the UVM."
  task :upgrade => "alpaca:insert_system_rules"
  task :upgrade => "db:migrate" do
    Alpaca::UvmDataLoader.new.load_settings

    ## Reload all of the managers
    os = Alpaca::OS.current_os
    Dir.new( "#{RAILS_ROOT}/lib/os_library" ).each do |manager|
      next if /_manager.rb$/.match( manager ).nil?
      
      ## Load the manager for this os, this will complete all of the initialization at
      os["#{manager.sub( /.rb$/, "" )}"]
    end

    ## This is one of the few situations where /etc/hosts must be completely overwritten by the alpaca.
    host_string = `awk '{ hostname = $0 ; sub ( /\..*/, "", hostname ) ; print $0 " " hostname }' /etc/hostname`

    os["override_manager"].write_file( EtcHostFile, <<EOF )
# AUTOGENERATED BY UNTANGLE DO NOT MODIFY MANUALLY

127.0.0.1  localhost localhost.localdomain
127.0.0.1  #{host_string} hostname.marker.untangle.com

# The following lines are desirable for IPv6 capable hosts
# (added automatically by netbase upgrade)

::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF

    ## Commit the network settings only if there are interfaces setup.
    os["network_manager"].commit unless Interface.find( :first ).nil?
  end
end


