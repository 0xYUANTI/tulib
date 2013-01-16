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

-module(test_db).
-behaviour(tulib_gen_db).

-export([ do_delete/2
        , do_insert/2
        , do_lookup/2
        , init/1
        ]).

init(_)             -> {ok, []}.
do_delete(Lst, Elt) -> {ok, Lst -- [Elt]}.
do_insert(_,   42)  -> {error, 42};
do_insert(Lst, Elt) -> {ok, [Elt|Lst]}.
do_lookup(Lst, Elt) -> lists:member(Elt, Lst).

%%% Local Variables:
%%% erlang-indent-level: 2
%%% End:
