/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/barfight_trie_root.c $
 * Copyright (c) 2003-2007 Untangle, Inc. 
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

#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/list.h>
#include <mvutil/hash.h>

#include "trie/trie.h"
#include "trie/internal.h"

/* Something slightly larger than 1337 for speed */
#define TRIE_HASH_SIZE 2777

barfight_trie_t* barfight_trie_malloc     ( void )
{
    barfight_trie_t* trie;

    if ( ( trie = calloc( sizeof(barfight_trie_t*), 1 )) == NULL ) return errlogmalloc_null();

    return trie;
}

int            barfight_trie_init       ( barfight_trie_t* trie, int flags, void* item, int item_size, 
                                        barfight_trie_init_t* init, barfight_trie_destroy_t* destroy )
{
    if ( trie == NULL ) return errlogargs();
    
    trie->mem  = 0;
    trie->item_count = 0;
    
    /* Set the FREE flag if necessary */
    trie->flags = 0;

    if ( flags & NC_TRIE_COPY ) {
        if ( item_size == 0 ) return errlogargs();
        trie->flags |= NC_TRIE_COPY;
        if ( !(flags & NC_TRIE_FREE ) ) {
            errlog(ERR_WARNING,"TRIE: Not advisable to use NC_TRIE_COPY and not NC_TRIE_FREE\n");
        }
    }

    if ( flags & NC_TRIE_FREE    ) trie->flags |= NC_TRIE_FREE;    
    if ( flags & NC_TRIE_INHERIT ) trie->flags |= NC_TRIE_INHERIT;

    trie->item_size = item_size;

    trie->init = init;
    trie->destroy = destroy;
    
    /* Use a better hashing function */
    if ( ht_init( &trie->ip_element_table, TRIE_HASH_SIZE, int_hash_func, int_equ_func, 0 ) < 0 ) {
        return errlog( ERR_CRITICAL, "ht_init\n" );
    }
    
    if ( barfight_trie_level_init ( trie, &trie->root, NULL, 0, 0 ) < 0 ) {
        return errlog(ERR_CRITICAL,"barfight_trie_level_init\n");
    }
            
    struct in_addr null_addr = { .s_addr = 0 };
    if ( barfight_trie_init_data ( trie, &trie->root.base, item, &null_addr, 0 ) < 0 ) {
        return errlog(ERR_CRITICAL,"barfight_trie_copy_item");
    }

    return 0;
}

barfight_trie_t* barfight_trie_create     ( int flags, void* item, int item_size, 
                                        barfight_trie_init_t* init,  barfight_trie_destroy_t* destroy )
{
    barfight_trie_t* trie;
    
    if (( trie = barfight_trie_malloc()) == NULL ) {
        return errlog_null ( ERR_CRITICAL,"barfight_trie_malloc\n");
    }
    
    if ( barfight_trie_init ( trie, flags, item, item_size, init, destroy ) < 0 ) {
        barfight_trie_free ( trie );
        return errlog_null ( ERR_CRITICAL,"barfight_trie_init\n");
    }
    
    return trie;
}

void           barfight_trie_free       ( barfight_trie_t* trie )
{
    if ( trie == NULL ) return(void)errlogargs();

    free ( trie );
}

void           barfight_trie_destroy    ( barfight_trie_t* trie )
{
    if ( trie == NULL ) return (void)errlogargs();

    if ( ht_destroy( &trie->ip_element_table ) < 0 ) perrlog( "ht_destroy" );

    barfight_trie_level_destroy ( trie, &trie->root );

    if ( trie->mem != 0 ) errlog (ERR_WARNING, "TRIE: root memory mismatch: %d\n", trie->mem);
    if ( trie->item_count != 0 ) errlog ( ERR_WARNING, "TRIE: root count mismatch: %d\n", trie->item_count );
}

void           barfight_trie_raze       ( barfight_trie_t* trie )
{
    if ( trie == NULL ) return(void)errlogargs();

    barfight_trie_destroy ( trie );
    
    barfight_trie_free ( trie );
}

void* barfight_trie_data( barfight_trie_t* trie )
{
    if ( trie == NULL ) return errlogargs_null();
    
    return trie->root.base.data;
}

int barfight_trie_internal_insert( barfight_trie_t* trie, barfight_trie_element_t element )
{
    int status;

    if ( trie == NULL || element.base == NULL ) return errlogargs();

    switch ( element.base->type ) {
    case NC_TRIE_BASE_LEVEL: trie->mem += sizeof(barfight_trie_level_t); break;
    case NC_TRIE_BASE_ITEM: trie->item_count++; break;        
    default:
        return errlog( ERR_WARNING,"TRIE: Uknown item type inserted (%d)\n", status );
    }

    return 0;
}

int            barfight_trie_remove_all ( barfight_trie_t* trie )
{
    if ( trie == NULL ) return errlogargs();
    
    _data_destroy ( trie, (barfight_trie_element_t)&trie->root );
    
    if ( barfight_trie_level_remove_all ( trie, &trie->root ) < 0 ) {
        return errlog(ERR_CRITICAL,"barfight_trie_level_remove_all\n");
    }
    
    return 0;
}

int            barfight_trie_internal_remove     ( barfight_trie_t* trie, barfight_trie_element_t element )
{
    if ( trie == NULL || element.base == NULL ) return errlogargs();

    switch ( element.base->type ) {
    case NC_TRIE_BASE_LEVEL:
        if ( trie->mem  < sizeof (barfight_trie_level_t)) {
            errlog(ERR_WARNING,"TRIE: Invalid amount of memory used\n");
        }
        
        trie->mem = MAX( 0, trie->mem - sizeof(barfight_trie_level_t));
        break;

    case NC_TRIE_BASE_ITEM:
        if ( trie->item_count  < 1) errlog(ERR_WARNING,"TRIE: Invalid item_count\n");        
        trie->item_count = MAX ( 0, trie->item_count -1);
        break;
        
    default:
        return errlog( ERR_WARNING,"TRIE: Uknown item type removed (%d)\n", element.base->type );
    }

    return 0;
}


