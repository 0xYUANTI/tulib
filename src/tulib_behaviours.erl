%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Utilities for working with Erlang behavio(u)rs.
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
-module(tulib_behaviours).

%%%_* Exports ==========================================================
-export([ add_args/2
        , extend/2
        , implements_attr/2
        , implements_duck/2
        , implements/2
        ]).

%%%_* Includes =========================================================
-include_lib("eunit/include/eunit.hrl").

%%%_* Code =============================================================
%%%_ * Types -----------------------------------------------------------
-type callbacks() :: [{atom(), integer()}].
-type behaviour() :: module().

%%%_ * API -------------------------------------------------------------
-spec add_args(behaviour(), integer()) -> callbacks().
%% @doc Rewrite behaviour info to account for e.g. implicit
%% parameterized module arguments.
add_args(Module, ArityDelta) ->
  [{Function, Arity + ArityDelta} ||
    {Function, Arity} <- Module:behaviour_info(callbacks)].

-spec extend(behaviour(), callbacks()) -> callbacks().
%% @doc Inherit from Module and add NewCallbacks.
extend(Module, NewCallbacks) ->
  Module:behaviour_info(callbacks) ++ NewCallbacks.

cover_test() ->
  _ = add_args(tulib_gen_db, 1),
  _ = extend(tulib_gen_db, []).


-spec implements_attr(module(), behaviour()) -> boolean().
%% @doc Indicate whether Module claims to implement Behaviour.
implements_attr(Module, Behaviour) ->
  Behaviours = [Vs || {K, Vs} <- Module:module_info(attributes),
                      is_behaviour_attribute(K)],
  lists:member(Behaviour, lists:flatten(Behaviours)).

-spec implements_duck(module(), behaviour()) -> boolean().
%% @doc Indicate whether Module seems to implement Behaviour.
implements_duck(Module, Behaviour) ->
  Callbacks = Behaviour:behaviour_info(callbacks),
  Exports   = Module:module_info(exports),
  lists:all(fun(Callback) -> lists:member(Callback, Exports) end, Callbacks).

-spec implements(module(), behaviour()) -> boolean().
%% @doc Indicate whether Module implements Behaviour.
implements(Module, Behaviour) ->
  implements_attr(Module, Behaviour) andalso
  implements_duck(Module, Behaviour).

implements_test() -> true = implements(test_db, tulib_gen_db).

%%%_ * Helpers ---------------------------------------------------------
is_behaviour_attribute(behaviour) -> true;
is_behaviour_attribute(behavior)  -> true;
is_behaviour_attribute(_)         -> false.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
