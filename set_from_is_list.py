#! /usr/bin/python
#
# Copyright (C) 2001-2018 by the Free Software Foundation, Inc.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software 
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

"""Reset a list's web_page_url attribute to the default setting.

This script is intended to be run as a bin/withlist script, i.e.

% bin/withlist -l -r set_from_is_list listname [options]

Options:
    -u value
    --from-is-list-value=value
        Set from_is_list value. Choices for value:
          0 = Accept (default)
          1 = Munge From
          2 = Wrap Message
          3 = Reject
          4 = Discard

    -v / --verbose
        Print what the script is doing.

If run standalone, it prints this help text and exits.
"""

import sys
import getopt

import paths
from Mailman import mm_cfg
from Mailman.i18n import C_




def usage(code, msg=''):
    print C_(__doc__.replace('%', '%%'))
    if msg:
        print msg
    sys.exit(code)




def set_from_is_list(mlist, *args):
    try:
        opts, args = getopt.getopt(args, 'u:v', ['from-is-list-value=', 'verbose'])
    except getopt.error, msg:
        usage(1, msg)

    verbose = 0
    f_value = 0
    for opt, arg in opts:
        if opt in ('-u', '--from-is-list-value'):
            f_value = int(arg)
        elif opt in ('-v', '--verbose'):
            verbose = 1

    # Make sure list is locked.
    if not mlist.Locked():
        if verbose:
            print C_('Locking list')
        mlist.Lock()

    if verbose:
        old_f_value = mlist.from_is_list
        print C_('Setting from_is_list from: %(old_f_value)s to: %(f_value)s')
    mlist.from_is_list = f_value
    print C_('Saving list')
    mlist.Save()
    mlist.Unlock()




if __name__ == '__main__':
    usage(0)
