/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/barfight_trie_base.c $
 * Copyright (c) 2003-2008 Untangle, Inc. 
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License, version 2,
 * as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
 * NONINFRINGEMENT.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <stdlib.h>
#include <time.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/list.h>

#include "trie/trie.h"
#include "trie/internal.h"


int  barfight_trie_base_init  ( barfight_trie_t* trie, barfight_trie_base_t* base, barfight_trie_level_t* parent, 
                              u_char type, u_char pos, u_char depth )
{
    if ( trie == NULL || base == NULL ) return errlogargs();

    base->type     = type;
    base->pos      = pos;
    base->depth    = depth;
    base->data     = NULL;
    base->parent   = parent;
    
    return 0;
}

void barfight_trie_base_destroy ( barfight_trie_t* trie, barfight_trie_base_t* base )
{
    if ( trie == NULL || base == NULL ) {
        errlogargs();
        return;
    }

    /* Clear out all of the pointers */
    base->parent = NULL;
    
    /* If necessary free the associated item */
    _data_destroy ( trie, (barfight_trie_element_t)base );
}

/* Returns the number of children that an item has (1 for terminal nodes) */
int  barfight_trie_element_children( barfight_trie_element_t element )
{
    if ( element.base == NULL ) {
        return errlogargs();
    }

    switch ( element.base->type ) {
    case NC_TRIE_BASE_LEVEL:
        return element.level->num_children;

    case NC_TRIE_BASE_ITEM:
        return 1;

    default:
        break;
    }

    return errlog( ERR_CRITICAL, "Invalid base item(type: %d)\n", element.base->type );    
}

void barfight_trie_element_destroy ( barfight_trie_t* trie, barfight_trie_element_t element ) {
    if ( trie == NULL || element.base == NULL ) {
        errlogargs();
        return;
    }

    switch ( element.base->type ) {
    case NC_TRIE_BASE_LEVEL:
        barfight_trie_level_destroy ( trie, element.level );
        break;

    case NC_TRIE_BASE_ITEM:
        barfight_trie_item_destroy ( trie, element.item );
        break;

    default:
        errlog(ERR_CRITICAL, "TRIE: Trying to destroy an unknown structure: %d\n", element.base->type );
    }
}

void barfight_trie_element_raze    ( barfight_trie_t* trie, barfight_trie_element_t element ) {
    if ( trie == NULL || element.base == NULL ) {
        errlogargs();
        return;
    }

    switch ( element.base->type ) {
    case NC_TRIE_BASE_LEVEL:
        barfight_trie_level_raze ( trie, element.level );
        break;

    case NC_TRIE_BASE_ITEM:
        barfight_trie_item_raze ( trie, element.item );
        break;

    default:
        errlog(ERR_CRITICAL, "TRIE: Trying to raze an unknown structure: %#010x %d\n", element, 
               element.base->type );
    }
}

