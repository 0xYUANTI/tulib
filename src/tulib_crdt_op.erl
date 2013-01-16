%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Op-based CRDT behaviour.
%%% @reference http://hal.inria.fr/docs/00/61/73/41/PDF/RR-7687.pdf
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
-module(tulib_crdt_op).

%%%_* Exports ==========================================================
-export([ behaviour_info/1
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").

%%%_* Code =============================================================
behaviour_info(callbacks) ->
  [ {s0,  0} %initial state
  , {q,   1} %query
  , {t,   2} %prepare-update
  , {u,   2} %effect-update
  , {'P', 2} %precondition
  ];
behaviour_info(_) -> undefined.

%%%_* Tests ============================================================
-ifdef(TEST).

cover_test() ->
  _ = behaviour_info(callbacks),
  _ = behaviour_info(foo).

-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
