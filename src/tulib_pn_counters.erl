%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Replicated integers.
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
-module(tulib_pn_counters).
-behaviour(tulib_crdt_state).

%%%_* Exports ==========================================================
%% API
-export([ dec/2
        , inc/2
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

-export_type([ np_counter/0
             ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").

%%%_* Code =============================================================
%%%_ * API -------------------------------------------------------------
dec(Cntr, Y) when is_integer(Y) , Y > 0 -> u(Cntr, {dec, Y}).
inc(Cntr, Y) when is_integer(Y) , Y > 0 -> u(Cntr, {inc, Y}).
new()                                   -> s0().
merge(Cntr1, Cntr2)                     -> m(Cntr1, Cntr2).
val(Cntr)                               -> q(Cntr).

%%%_ * crdt_state callbacks --------------------------------------------
-define(C, tulib_g_counters).

-opaque np_counter()     :: {?C:g_counter(), ?C:g_counter()}.

'=<'({P1, N1}, {P2, N2}) -> ?C:'=<'(P1, P2) andalso ?C:'=<'(N1, N2).

s0()                     -> {?C:s0(), ?C:s0()}.

u({P, N}, {inc, X})      -> {?C:inc(P, X), N};
u({P, N}, {dec, X})      -> {P, ?C:inc(N, X)}.

q({P, N})                -> ?C:val(P) - ?C:val(N).

m({P1, N1}, {P2, N2})    -> {?C:merge(P1, P2), ?C:merge(N1, N2)}.

%%%_* Tests ============================================================
-ifdef(TEST).

api_test() ->
  C0 = new(),
  0  = val(C0),
  C1 = dec(inc(C0, 42), 41),
  1  = val(C1),
  C  = merge(C0, C1),
  1  = val(C),
  ok.

callbacks_test() ->
  Zero  = tulib_g_counters:new(),
  One   = tulib_g_counters:inc(Zero, 1),
  true  = '=<'({Zero, Zero}, {Zero, One}),
  false = '=<'({Zero, One}, {Zero, Zero}),
  ok.

-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
