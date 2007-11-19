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
module NUCLICommon

# Misc Constants
BRAND = "Untangle"

# Shared Error Messages
ERROR_INCOMPLETE_COMMAND = "Error: incomplete command -- missing required arguments (see help.)"
ERROR_UNKNOWN_COMMAND = "Error: unknown command"
ERROR_COMMAND_FAILED = "Error: unable to execute command"
ERROR_INVALID_NODE_ID = "Error: invalid node identifier"


# Shared Exceptions
class CommandFailed < Exception
end

class Terminate < Exception
end

end
