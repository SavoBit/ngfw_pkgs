#
# $HeadURL: svn://chef/work/pkgs/untangle-net-alpaca/files/var/lib/rails/untangle-net-alpaca/db/migrate/010_thunderbird.rb $
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
class ThunderbirdRC1 < Alpaca::Migration
  def self.up
    ## Join between an IP network and a PPPoE configuration.
    create_table :intf_pppoes_ip_networks, :id => false do |table|
      table.column :intf_pppoe_id, :integer
      table.column :ip_network_id, :integer
    end
  end

  def self.down
    drop_table :intf_pppoes_ip_networks
  end
end
