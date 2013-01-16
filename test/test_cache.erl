%%%
%%%   Copyright 2011-2013 Klarna AB
%%%
%%%   Licensed under the Apache License, Version 2.0 (the "License");
%%%   you may not use this file except in compliance with the License.
%%%   You may obtain a copy of the License at
%%%
%%%       http://www.apache.org/licenses/LICENSE-2.0
%%%
%%%   Unless required by applicable law or agreed to in writing, software
%%%   distributed under the License is distributed on an "AS IS" BASIS,
%%%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%%   See the License for the specific language governing permissions and
%%%   limitations under the License.
%%%

-module(test_cache).
-behaviour(tulib_gen_cache).

-export([ hit/2
        , init/1
        , invalid/2
        , miss/2
        , replace/2
        ]).

-export([ fetch/2
        , store/3
        ]).

-export([ insert/3
        , invalidate/2
        , lookup/2
        , start/0
        , start_link/0
        , stop/0
        ]).

hit('', _)           -> ''.
init(_)              -> tulib_processes:spawn_register(fun dict/0, xyzzy),
                        tulib_processes:sync_registered(xyzzy),
                        ''.
invalid('', _)       -> ''.
miss('', _)          -> ''.
replace('', _)       -> {'', []}.

fetch(Tab, Key)      -> tulib_processes:call(xyzzy, {fetch, Tab, Key}).
store(Tab, Key, Val) -> tulib_processes:send(xyzzy, {store, Tab, Key, Val}).

dict() ->
  receive
    {Pid, {fetch, Tab, Key}} ->
      ok = tulib_processes:send(Pid, get({Tab, Key})),
      dict();
    {_Pid, {store, Tab, Key, Val}} ->
      put({Tab, Key}, Val),
      dict()
  end.


invalidate(_, _) -> throw(nyi).
insert(_, _, _)  -> throw(nyi).
lookup(_, _)     -> throw(nyi).
start()          -> throw(nyi).
start_link()     -> throw(nyi).
stop()           -> throw(nyi).

%%% Local Variables:
%%% erlang-indent-level: 2
%%% End:
