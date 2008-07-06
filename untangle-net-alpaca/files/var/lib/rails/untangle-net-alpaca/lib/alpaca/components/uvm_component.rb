#
# $HeadURL$
# Copyright (c) 2007-2008 Untangle, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
# NONINFRINGEMENT.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
class Alpaca::Components::UvmComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    if ( config_level >= AlpacaSettings::Level::Advanced ) 
      menu_organizer.register_item( "/main/advanced/uvm", menu_item( 300, "Bypass Rules", {} ))
    end
  end

  def wizard_insert_closers( builder )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 1900 ) { save } )
  end
  
  def update_interfaces( interface_list )
    uvm_settings = UvmSettings.find( :first )
    uvm_settings = UvmSettings.new( :interface_order => UvmHelper::DefaultOrder ) if uvm_settings.nil?

    ## Update the settings
    intf_order = uvm_settings.interface_order
    
    ## Just in case the interface order is somehow nil?
    intf_order = UvmHelper::DefaultOrder if intf_order.nil?

    puts "Interface order: #{intf_order}"
    puts "Interface list: #{interface_list.map{ |i| i.index }.join( ",")}"

    intf_order = intf_order.split( "," ).map { |idx| idx.to_i }.delete_if { |idx| idx == 0 }
    
    ## Iterate the available interfaces and add them manually.
    interfaces = {}
    interface_list.each { |interface| interfaces[interface.index] = interface }

    puts "Interface list: #{interfaces.keys.join( "," )}"

    ## Find all of the interfaces that exist
    new_intf_order = []
    intf_order.each do |i|
      next if interfaces[i].nil? && ( i != UvmHelper::VpnIndex )
      new_intf_order << i

      ## Delete the interface from interfaces.
      interfaces.delete( i ) 
    end

    ## Now add all of the interfaces that are not there. (beginning of the list)
    puts "Interface list: #{interfaces.keys.join( "," )}"
    interfaces.keys.sort.each{ |i| new_intf_order = [i] + new_intf_order }
    
    uvm_settings.interface_order = new_intf_order.join( "," )
    uvm_settings.save

    os["uvm_manager"].write_files
  end

  private
  def save
    update_interfaces( Interface.find( :all ))
  end
end
