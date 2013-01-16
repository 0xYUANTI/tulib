%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Increment-only counters.
%%% @reference http://pagesperso-systeme.lip6.fr/Marc.Shapiro/papers/
%%%                                      Comprehensive-CRDTs-RR7506-2011-01.pdf
%%% Access must be serialized on each node (e.g. by a per-node counter server).
%%% @copyright 2012 Klarna AB
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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

%%%_* Module declaration ===============================================
-module(tulib_g_counters).
-behaviour(tulib_crdt_state).

%%%_* Exports ==========================================================
%% API
-export([ inc/2
        , new/0
        , merge/2
        , val/1
        ]).

%% crdt_state callbacks
-export([ '=<'/2
        , s0/0
        , q/1
        , u/2
        , m/2
        ]).

-export_type([ g_counter/0
             ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").

%%%_* Code =============================================================
%%%_ * API -------------------------------------------------------------
inc(Cntr, Y) when is_integer(Y) , Y > 0 -> u(Cntr, Y).
new()                                   -> s0().
merge(Cntr1, Cntr2)                     -> m(Cntr1, Cntr2).
val(Cntr)                               -> q(Cntr).

%%%_ * crdt_state callbacks --------------------------------------------
-opaque g_counter()  :: [{node(), non_neg_integer()}].

'=<'([],          []   ) -> true;
'=<'([],          [_|_]) -> true;
'=<'([_|_],       []   ) -> false;
'=<'([{S, X}|C1], C2   ) ->
  X =< tulib_lists:assoc(S, C2, 0) andalso
    '=<'(C1, tulib_lists:assoc_delete(S, C2)).

s0() -> [].

u(C, Y) -> tulib_lists:assoc_update(node(), fun(X) -> X + Y end, 0, C).

q(C) -> lists:sum([X || {_S, X} <- C]).

m([],          []) -> [];
m([],          C2) -> C2;
m(C1,          []) -> C1;
m([{S, X}|C1], C2) ->
  [{S, max(X, tulib_lists:assoc(S, C2, 0))}|
   m(C1, tulib_lists:assoc_delete(S, C2))].

%%%_* Tests ============================================================
-ifdef(TEST).

api_test() ->
  C0 = new(),
  0  = val(C0),
  C1 = inc(C0, 1),
  1  = val(C1),
  C  = merge(C0, C1),
  1  = val(C),
  ok.

callbacks_test() ->
  false = '=<'([{node1, 42}], [{node1, 41}]),
  true  = '=<'([{node1, 42}], [{node1, 42}]),
  true  = '=<'([{node1, 0}],  [{node2, 42}]), %\ should never have an
  false = '=<'([{node1, 0}],  []),            %/ explicit zero entry
  false = '=<'([{node1, 1}],  [{node2, 42}]),
  true  = '=<'(m([{node1, 42}], [{node2, 42}]),
               m([{node2, 42}], [{node1, 42}])),
  false = '=<'(m([{node1, 42}], [{node1, 43}]),
               m([{node1, 42}], [])),
  ok.

-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
