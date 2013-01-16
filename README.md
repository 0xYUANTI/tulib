     _____ _   _ _ _ _
    |_   _| | | | (_) |__
     | | | | | | | | '_ \
     | | | |_| | | | |_) |
     |_|  \___/|_|_|_.__/

## Overview
TUlib is Klarna's standard Erlang libary.

ALPHA -- work in progress

BETA  -- not used in production

Written by Jakob Sievers, with contributions by

* Bjorn Jensen-Urstad (/b3rnie)
* Daniel K. Lee (/dklee)
* Thomas Jarvstrand (/tjarvstrand)

## Installation
jakob@drunken.primat.es:~/git/klarna/tulib$ gmake

jakob@drunken.primat.es:~/git/klarna/tulib$ gmake test

## Manifest
* include/
    * assert.hrl            -- Assertions
    * bit.hrl               -- Bit manipulation
    * guards.hrl            -- Predicate macros
    * logging.hrl           -- Wrappers for various logging packages
    * metrics.hrl           -- Wrappers for various metrics packages
    * prelude.hrl           -- Convenience
    * types.hrl             -- Common types

* src/
    * tulib_atoms.erl       -- Atom utilities
    * tulib_call.erl        -- Wrappers around erlang:apply/2,3
    * tulib_combinators.erl -- Some standard higher-order functions
    * tulib_csets.erl       -- Counting sets
    * tulib_deployer.erl    -- A gen_server which loads code on remote nodes
    * tulib_dlogs.erl       -- A simplified interface to disk_log
    * tulib_export.erl      -- Some hacks for calling functions which aren't exported
    * tulib_fs.erl          -- Filesystem utilities
    * tulib_gen_cache.erl   -- Generic cache
    * tulib_gen_db.erl      -- A behaviour for simple, fault-tolerant data stores
    * tulib_gen_lb.erl      -- Generic load-balancer
    * tulib_gen_proxy.erl   -- Generic proxy
    * tulib_lists.erl       -- List utilities
    * tulib_loops.erl       -- Iteration-related higher-order functions
    * tulib_maybe.erl       -- Disciplined error handling
    * tulib_nodes.erl       -- Start and stop Erlang nodes from Erlang
    * tulib_par.erl         -- Parallel computation
    * tulib_predicates.erl  -- Functions which return true or false
    * tulib_processes.erl   -- Wrappers around !/receive
    * tulib_random.erl      -- Random numbers and such
    * tulib_sh.erl          -- Shell commands
    * tulib_sockets.erl     -- A simplified interface to gen_tcp
    * tulib_strings.erl     -- String utilities
    * tulib_util.erl        -- Misc
    * tulib_vclocks.erl     -- Generic vector clocks
