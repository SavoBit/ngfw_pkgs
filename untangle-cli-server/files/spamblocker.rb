#
# $HeadURL:$
# Copyright (c) 2003-2007 Untangle, Inc. 
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
require 'filternode'
include_class(['com.untangle.node.spam.SpamProtoConfig',
              'com.untangle.node.spam.SpamMessageAction',
              'com.untangle.node.spam.SMTPSpamMessageAction'])

class SpamBlocker < UVMFilterNode
  include CmdDispatcher
  include RetryLogin

  ERROR_NO_SPAMBLOCKER_NODES = "No Spam Blocker modules are installed on the effective server."
  NODE_NAME = "untangle-node-spamassassin"
  # TODO check with Ken the real MIB for spamblocker
  SPAMBLOCKER_MIB_ROOT = UVM_FILTERNODE_MIB_ROOT + ".5"

  @@strengthValues = {
    "low" => SpamProtoConfig::LOW_STRENGTH,
    "medium" =>  SpamProtoConfig::MEDIUM_STRENGTH,
    "high" => SpamProtoConfig::HIGH_STRENGTH,
    "very-high" => SpamProtoConfig::VERY_HIGH_STRENGTH,
    "extreme" => SpamProtoConfig::EXTREME_STRENGTH
  }
  
  @@spamActionValues = {
    "mark" => SpamMessageAction::MARK,
    "pass" => SpamMessageAction::PASS
  }

  @@smtpSpamActionValues = {
    "mark" => SMTPSpamMessageAction::MARK,
    "pass" => SMTPSpamMessageAction::PASS,
    "block" =>  SMTPSpamMessageAction::BLOCK,
    "quarantine" => SMTPSpamMessageAction::QUARANTINE
  }

  def initialize
    @diag = Diag.new(DEFAULT_DIAG_LEVEL)
    @diag.if_level(3) { puts! "Initializing #{get_node_name()}..." }
    super
    @diag.if_level(3) { puts! "Done initializing #{get_node_name()}..." }
  end
  
  def get_uvm_node_name()
    NODE_NAME
  end
  
  def get_node_name()
    "Spam Blocker"
  end
  
  def get_mib_root()
    SPAMBLOCKER_MIB_ROOT
  end  
  
  def execute(args)
    # TODO: BUG: if we don't return something the client reports an exception
    @diag.if_level(3) { puts! "SpamBlocker::execute(#{args.join(', ')})" }

    begin
      retryLogin {
        # Get tids of all spam blockers once and for all commands we might execute below.
        tids = get_filternode_tids(get_uvm_node_name())
        if empty?(tids) then return (args[0] == "snmp") ? nil : ERROR_NO_SPAMBLOCKER_NODES ; end

        begin
          tid, cmd = *extract_tid_and_command(tids, args, ["snmp"])
        rescue InvalidNodeNumber, InvalidNodeId => ex
            msg = ERROR_INVALID_NODE_ID + ": " + ex
            @diag.if_level(3) { puts! msg ; p ex}
            return msg
        rescue Exception => ex
          msg = "Error: spamblocker encountered an unhandled exception: " + p
        end
        @diag.if_level(3) { puts! "TID = #{tid}, command = #{cmd}" }

        return dispatch_cmd(args.empty? ? [cmd, tid] : [cmd, tid, *args])
      }
    rescue Exception => ex
      @diag.if_level(3) { puts! ex; puts! ex.backtrace }
      return "Uncaught exception #{ex}"
    end    
  end

  # Default command: list all span blocker FNs
  # TODO: we should consider moving this method to UVMFilterNode class
  def cmd_(*args)
    return list_filternodes()
  end
  
  protected
  def cmd_help(tid, *args)
    return <<HELP
- spamblocker -- enumerate all spam blocker nodes running on effective #{BRAND} server.
- spamblocker <#X|TID> [protocol:SMTP|POP|IMAP]
    -- Display email scanning and quarantine options for node #X|TID and the specified protocol.
- spamblocker <#X|TID> [protocol:SMTP|POP|IMAP] update [key:scan|strength|action|tarpit|description] new_value
    -- Update email scanning and quarantine options with specified settings:
      scan:true|false
      strength:low|medium|high|very-high|extreme
      action:mark|pass|block|quarantine for SMTP and mark|pass for POP and IMAP
      tarpit:true|false available only for SMTP
      description:any string
- spamblocker <#X|TID> <snmp|stats>
    -- Display spam blocker #X|TID statistics
HELP
  end

  def cmd_SMTP(tid)
    display_settings(tid, "SMTP")
  end

  def cmd_POP(tid)
    display_settings(tid, "POP")
  end
  
  def cmd_IMAP(tid)
    display_settings(tid, "IMAP")
  end
  
  def cmd_SMTP_update(tid, key, value)
    update_protocol_setting(tid, "SMTP", key, value)
  end

  def cmd_POP_update(tid, key, value)
    update_protocol_setting(tid, "POP", key, value)
  end
  
  def cmd_IMAP_update(tid, key, value)
    update_protocol_setting(tid, "IMAP", key, value)
  end
  
  def cmd_snmp(tid, *args)
    get_statistics(tid, args)
  end

  def cmd_stats(tid, *args)
    get_statistics(tid, args)
  end
  
  def display_settings(tid, protocol)
    config = get_protocol_config(tid, protocol)
    ret = "scan,strength,action," << (protocol == "SMTP" ? "tarpit," : "") << "description\n"
    ret << "#{config.getScan.to_s}"
    ret << ",#{config.getStrengthByName}"
    ret << ",#{config.getMsgAction}"
    ret << ",#{config.getThrottle.to_s}" if (protocol == "SMTP")
    ret << ",#{config.getNotes}"
    ret << "\n"
    return ret
  end
  
  def update_protocol_setting(tid, protocol, key, new_value)
    config = get_protocol_config(tid, protocol)
    begin
      case key
      when "scan"
        validate_bool(new_value, "scan")
        config.setScan(new_value == "true")
      when "strength"
        validate_list(new_value, @@strengthValues.keys ,"strength")
        config.setStrength(@@strengthValues[new_value])
      when "action"
        actionValues = protocol == "SMTP" ? @@smtpSpamActionValues : @@spamActionValues
        validate_list(new_value, actionValues.keys ,"action")
        config.setMsgAction(actionValues[new_value])
      when "tarpit"
        raise "Error: invalid key for '#{protocol}'" if protocol != "SMTP"
        validate_bool(new_value, "tarpit")
        config.setThrottle(new_value == "true")
      when "description"
        config.setNotes(new_value)
      else
        raise "Error: invalid key for '#{protocol}'"
      end      
    rescue => ex
      return ex.to_s
    end
    update_spam_settings(tid, protocol, config)
    msg = "#{key} for #{protocol} updated."

    @diag.if_level(2) { puts! msg }
    return msg
  end
  

  #-- Helper methods
  def get_spam_settings(tid)
    @@uvmRemoteContext.nodeManager.nodeContext(tid).node.getSpamSettings
  end
  
  def get_protocol_config(tid, protocol)
    settings = get_spam_settings(tid)
    case protocol
    when "SMTP"
      settings.getSmtpConfig
    when "POP"
      settings.getPopConfig
    when "IMAP"
      settings.getImapConfig
    end
  end
  
  def update_spam_settings(tid, protocol, config)
    node = @@uvmRemoteContext.nodeManager.nodeContext(tid).node
    settings = node.getSpamSettings

    case protocol
    when "SMTP"
      settings.setSmtpConfig(config)
    when "POP"
      settings.setPopConfig(config)
    when "IMAP"
      settings.setImapConfig(config)
    end
    
    node.setSpamSettings(settings)
  end
  
end
